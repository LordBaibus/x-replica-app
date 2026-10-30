const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

// Takes the picture out of an images API answer (base64 or a URL).
async function pickImage(j: any): Promise<string | null> {
  const item = j?.data?.[0];
  if (item?.b64_json) return item.b64_json as string;
  if (item?.url) {
    const img = await fetch(item.url);
    return bytesToBase64(new Uint8Array(await img.arrayBuffer()));
  }
  return null;
}

function bytesToBase64(bytes: Uint8Array): string {
  let bin = "";
  const chunk = 0x8000;
  for (let i = 0; i < bytes.length; i += chunk) {
    bin += String.fromCharCode(...bytes.subarray(i, i + chunk));
  }
  return btoa(bin);
}

// "…the request was rejected by the safety system", "moderation_blocked"…
function isSafetyError(msg: string): boolean {
  return /safety|moderation|content[ _-]?policy|policy violation|not allowed|blocked/i
    .test(msg);
}

// A model the account does not have / cannot use for this call.
function isModelError(msg: string): boolean {
  return /does not exist|not found|unknown model|invalid model|not supported|unsupported|no access|do(es)? not have access|model_not_found/i
    .test(msg);
}

// Cut at a word boundary, never above [max] characters.
function clip(text: string, max: number): string {
  if (text.length <= max) return text;
  const cut = text.slice(0, max);
  const sp = cut.lastIndexOf(" ");
  return (sp > max * 0.6 ? cut.slice(0, sp) : cut).trimEnd();
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  const key = Deno.env.get("AI_API_KEY") ?? Deno.env.get("OPENAI_API_KEY");
  if (!key) return json({ error: "The AI helper has no API key yet." }, 500);

  const base = (Deno.env.get("AI_BASE_URL") ?? "https://api.openai.com/v1")
    .replace(/\/$/, "");
  const host = base.includes("api.openai.com")
    ? "openai"
    : base.includes("x.ai")
    ? "xai"
    : "other";
  const explicitChatModel = Deno.env.get("AI_CHAT_MODEL");
  const explicitImageModel = Deno.env.get("AI_IMAGE_MODEL");
  const headers = {
    "Content-Type": "application/json",
    Authorization: `Bearer ${key}`,
  };

  // ---- which models does this key have? ---------------------------------
  // Providers differ (and change) in what they offer, so ask them instead of
  // hard-coding names. Cached for a few minutes per function instance.
  const g = globalThis as unknown as {
    __models?: { at: number; ids: string[] };
  };
  async function availableModels(): Promise<string[]> {
    if (g.__models && Date.now() - g.__models.at < 5 * 60_000) {
      return g.__models.ids;
    }
    try {
      const r = await fetch(`${base}/models`, {
        headers: { Authorization: `Bearer ${key}` },
        signal: AbortSignal.timeout(15_000),
      });
      if (!r.ok) return [];
      const j = await r.json();
      const ids = ((j?.data ?? []) as { id?: string }[])
        .map((m) => String(m.id ?? ""))
        .filter(Boolean);
      g.__models = { at: Date.now(), ids };
      return ids;
    } catch {
      return [];
    }
  }

  const NOT_CHAT =
    /(image|dall-e|tts|whisper|audio|realtime|transcribe|embed|moderation|search|codex|instruct|davinci|babbage|computer|sora|video|vision-preview)/i;
  const CHAT_PREFERRED = [
    "gpt-5-mini",
    "gpt-4.1-mini",
    "gpt-4o-mini",
    "gpt-5",
    "gpt-4.1",
    "gpt-4o",
    "gpt-5-nano",
    "grok-4-fast",
    "grok-3-mini",
    "grok-3",
  ];

  async function chatCandidates(): Promise<string[]> {
    if (explicitChatModel) return [explicitChatModel];
    const ids = await availableModels();
    if (ids.length === 0) return ["gpt-4o-mini", "gpt-4.1-mini", "gpt-5-mini"];
    const ok = ids.filter((id) =>
      !NOT_CHAT.test(id) && /^(gpt|chatgpt|grok|o\d|claude|gemini|llama|mistral)/i.test(id)
    );
    const pref = CHAT_PREFERRED.filter((m) => ok.includes(m));
    const rest = ok.filter((m) => !pref.includes(m)).sort((a, b) => a.length - b.length);
    const all = [...pref, ...rest].slice(0, 5);
    return all.length ? all : ["gpt-4o-mini"];
  }

  async function imageCandidates(): Promise<string[]> {
    const ids = await availableModels();
    const fromAccount = ids
      .filter((id) => /image/i.test(id) && !/(vision|embed|edit-only)/i.test(id))
      .sort((a, b) => {
        // newest looking first: gpt-image-2.5 > gpt-image-1 > others
        const na = parseFloat(a.match(/(\d+(?:\.\d+)?)/)?.[1] ?? "0");
        const nb = parseFloat(b.match(/(\d+(?:\.\d+)?)/)?.[1] ?? "0");
        return nb - na;
      });
    const defaults = host === "xai"
      ? ["grok-2-image", "grok-2-image-1212"]
      : host === "openai"
      ? ["gpt-image-2.5-flare", "gpt-image-2.5-sunburst", "gpt-image-1"]
      : ["gpt-image-1", "gpt-image-2.5-flare", "grok-2-image"];
    // Models the account really has first; the usual names only when the
    // model list could not be read.
    const pool = fromAccount.length ? fromAccount : defaults;
    return [...new Set([explicitImageModel, ...pool])]
      .filter((m): m is string => !!m)
      .slice(0, 4);
  }

  // One chat completion, trying the next model when one is not available.
  async function chatComplete(messages: { role: string; content: unknown }[]): Promise<string> {
    const models = await chatCandidates();
    let lastError = "AI request failed.";
    for (const model of models) {
      let r: Response;
      try {
        // No temperature / max_tokens: newer models only accept the default.
        r = await fetch(`${base}/chat/completions`, {
          method: "POST",
          headers,
          body: JSON.stringify({ model, messages }),
          signal: AbortSignal.timeout(90_000),
        });
      } catch (e) {
        lastError = (e as Error).name === "TimeoutError"
          ? "The AI helper took too long. Try again."
          : `Could not reach the AI service: ${(e as Error).message}`;
        continue;
      }
      const j = await r.json().catch(() => ({}));
      if (r.ok) {
        const out = String(j?.choices?.[0]?.message?.content ?? "").trim();
        if (out) return out;
        lastError = `${model} returned an empty answer.`;
        continue;
      }
      lastError = `${model}: ${j?.error?.message ?? `request failed (${r.status})`}`;
      console.log(`chat model ${model} failed: ${r.status} ${lastError}`);
      // A wrong key or no credit fails for every model.
      if (r.status === 401 || r.status === 429) break;
    }
    throw new Error(lastError);
  }

  let body: {
    action?: string;
    text?: string;
    prompt?: string;
    messages?: { role?: string; content?: string }[];
    persona?: string;
    image?: string; // base64
    mime?: string;
  };
  try {
    body = await req.json();
  } catch {
    return json({ error: "Bad request." }, 400);
  }

  try {
    if (body.action === "enhance") {
      const text = (body.text ?? "").trim().slice(0, 1000);
      if (!text) return json({ error: "Write something first." }, 400);
      const out = await chatComplete([
        {
          role: "system",
          content:
            "You improve short social media posts. Rewrite the user's draft " +
            "so it is clearer and more engaging. Keep the same language, " +
            "meaning and voice. Do not add hashtags or emoji unless the draft " +
            "has them. The result must be at most 270 characters. Reply with " +
            "the post text only, without quotes.",
        },
        { role: "user", content: text },
      ]);
      return json({ text: clip(out.replace(/^["“]|["”]$/g, "").trim(), 280) });
    }

    if (body.action === "chat") {
      const history = (body.messages ?? [])
        .filter((m) => (m.content ?? "").trim().length > 0)
        .slice(-20)
        .map((m) => ({
          role: m.role === "assistant" ? "assistant" : "user",
          content: String(m.content).slice(0, 4000),
        }));
      if (history.length === 0) return json({ error: "Ask something first." }, 400);
      const persona = (body.persona ?? "").trim().slice(0, 300);
      // A photo belongs to the newest user message.
      const msgs: { role: string; content: unknown }[] = [...history];
      if (body.image) {
        const last = msgs[msgs.length - 1];
        msgs[msgs.length - 1] = {
          role: "user",
          content: [
            { type: "text", text: String(last.content) },
            {
              type: "image_url",
              image_url: { url: `data:${body.mime ?? "image/jpeg"};base64,${body.image}` },
            },
          ],
        };
      }
      const out = await chatComplete([
        {
          role: "system",
          content:
            "You are Grok, the built-in assistant of X Replica, a student " +
            "project that imitates a social network. Be helpful, direct and a " +
            "little witty. Keep answers short unless asked for detail. If asked " +
            "which model you run on, say you are an AI assistant powered by " +
            "OpenAI. Plain text only: no markdown headings or tables." +
            (persona ? ` For this chat, also play the role of ${persona}` : ""),
        },
        ...msgs,
      ]);
      return json({ text: out });
    }

    if (body.action === "image") {
      const prompt = (body.prompt ?? "").trim().slice(0, 1000);
      if (!prompt) return json({ error: "Describe the image first." }, 400);
      const models = await imageCandidates();

      // Tries every model with [text]. Returns the picture, or the errors.
      async function attempt(text: string) {
        const errors: string[] = [];
        for (const model of models) {
          const payload: Record<string, unknown> = { model, prompt: text, n: 1 };
          if (host === "xai") {
            payload.response_format = "b64_json"; // xAI takes no size / quality
          } else {
            payload.size = "1024x1024";
            // gpt-image-* takes `quality` (medium is much faster than high);
            // newer models reject `response_format`, so it is not sent.
            if (model.startsWith("gpt-image")) payload.quality = "medium";
          }
          let r: Response;
          try {
            r = await fetch(`${base}/images/generations`, {
              method: "POST",
              headers,
              body: JSON.stringify(payload),
              signal: AbortSignal.timeout(110_000),
            });
          } catch (e) {
            errors.push(
              (e as Error).name === "TimeoutError"
                ? "The image took too long to make. Try a simpler description."
                : `Could not reach the image service: ${(e as Error).message}`,
            );
            continue;
          }
          const j = await r.json().catch(() => ({}));
          if (r.ok) {
            const img = await pickImage(j);
            if (img) return { image: img, errors };
            errors.push("The provider returned no image.");
            continue;
          }
          const msg = j?.error?.message ?? `Image request failed (${r.status}).`;
          errors.push(`${model}: ${msg}`);
          console.log(`image model ${model} failed: ${r.status} ${msg}`);
          // A wrong key or no credit will fail for every model: stop here.
          if (r.status === 401 || r.status === 429) break;
        }
        return { image: null as string | null, errors };
      }

      let res = await attempt(prompt);
      if (res.image) return json({ image: res.image });

      // The safety system refuses many names (trademarked characters, real
      // people, brands). Describe the same picture without names and retry.
      if (res.errors.some(isSafetyError)) {
        try {
          const generic = await chatComplete([
            {
              role: "system",
              content:
                "Rewrite the user's image idea as a detailed, purely visual " +
                "description for an image generator. Never use names of real " +
                "people, trademarked characters, brands or franchises: describe " +
                "how they look instead (clothing, colours, pose, setting, art " +
                "style). Keep it safe for work. Reply with the description only, " +
                "at most 80 words.",
            },
            { role: "user", content: prompt },
          ]);
          res = await attempt(generic.slice(0, 1000));
          if (res.image) return json({ image: res.image, note: "reworded" });
        } catch (e) {
          console.log(`rewording failed: ${(e as Error).message}`);
        }
        return json({
          error:
            "The image service refused this description (it blocks some " +
            "names, brands and characters). Describe the picture in your own " +
            "words instead, for example “a muscular thunder god with a winged " +
            "helmet and a hammer, comic-book style”.",
        }, 502);
      }

      const unique = [...new Set(res.errors)];
      // Models missing from the account are not useful to show.
      const useful = unique.filter((e) => !isModelError(e));
      return json({
        error: (useful.length ? useful : unique).slice(0, 2).join(" | ") ||
          "Image request failed.",
      }, 502);
    }

    if (body.action === "edit") {
      const prompt = (body.prompt ?? "").trim().slice(0, 1000);
      if (!prompt || !body.image) {
        return json({ error: "Send a picture and describe the change." }, 400);
      }
      const mime = body.mime ?? "image/png";
      const ext = mime.includes("jpeg") || mime.includes("jpg") ? "jpg" : mime.includes("webp") ? "webp" : "png";
      const bytes = Uint8Array.from(atob(body.image), (c) => c.charCodeAt(0));
      const models = await imageCandidates();
      const errors: string[] = [];
      for (const model of models) {
        const form = new FormData();
        form.append("model", model);
        form.append("prompt", prompt);
        form.append("image", new Blob([bytes], { type: mime }), `image.${ext}`);
        // No Content-Type here: fetch adds the multipart boundary itself.
        const r = await fetch(`${base}/images/edits`, {
          method: "POST",
          headers: { Authorization: `Bearer ${key}` },
          body: form,
          signal: AbortSignal.timeout(110_000),
        }).catch(() => null);
        if (!r) {
          errors.push("Could not reach the image service.");
          continue;
        }
        const j = await r.json().catch(() => ({}));
        if (r.ok) {
          const img = await pickImage(j);
          if (img) return json({ image: img });
          errors.push("The provider returned no image.");
          continue;
        }
        const msg = j?.error?.message ?? `Image edit failed (${r.status}).`;
        errors.push(`${model}: ${msg}`);
        if (r.status === 401 || r.status === 429) break;
      }
      if (errors.some(isSafetyError)) {
        return json({
          error:
            "The image service refused this edit (it blocks some names, " +
            "brands and people). Try describing the change differently.",
        }, 502);
      }
      return json({ error: [...new Set(errors)].slice(0, 2).join(" | ") || "Image edit failed." }, 502);
    }

    return json({ error: "Unknown action." }, 400);
  } catch (e) {
    return json({ error: (e as Error).message || "AI helper error." }, 502);
  }
});
