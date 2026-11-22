// Shared deadlines, teardown and error classification for the performance runners.
export function within(promise, ms, what) {
  let timer;
  const deadline = new Promise((_, reject) => {
    timer = setTimeout(() => reject(new Error(`${what}: no answer in ${ms / 1000} s`)), ms);
  });
  return Promise.race([promise, deadline]).finally(() => clearTimeout(timer));
}

export function isError(line) {
  return /^\[(error|pageerror)\]/.test(line) || /\bERROR\b/.test(line) ||
    /\b(?:GL_)?(?:INVALID_ENUM|INVALID_VALUE|INVALID_OPERATION|INVALID_FRAMEBUFFER_OPERATION|OUT_OF_MEMORY)\b/.test(line);
}

export async function close(holder, name, ms = 30000) {
  if (holder.closed) return;
  try {
    await within(holder.server.close(), ms, 'browser.close');
  } catch (error) {
    console.error(`${name}: ${error.message}; killing this browser`);
    await within(holder.server.kill(), ms, 'browser.kill');
  }
  holder.closed = true;
}

export async function launch(name, cfg = {}) {
  if (!['chrome', 'firefox'].includes(name)) throw new Error(`Unknown browser: ${name}`);
  const { chromium, firefox } = await import(process.env.PLAYWRIGHT_MODULE ?? 'playwright');
  const type = name === 'chrome' ? chromium : firefox;
  const server = await type.launchServer(name === 'chrome'
    ? { executablePath: process.env.CHROME ?? '/usr/bin/google-chrome', headless: false, host: '127.0.0.1', timeout: 30000,
      args: ['--autoplay-policy=no-user-gesture-required', '--enable-unsafe-swiftshader',
        '--disable-background-timer-throttling', '--disable-renderer-backgrounding',
        '--disable-backgrounding-occluded-windows',
        ...(cfg.uncap ? ['--disable-gpu-vsync', '--disable-frame-rate-limit'] : [])] }
    : { headless: false, host: '127.0.0.1', timeout: 30000, firefoxUserPrefs: {
      'media.autoplay.default': 0, ...(cfg.firefoxPrefs ?? {}),
    } });
  const holder = { server, closed: false };
  try {
    holder.browser = await within(type.connect(server.wsEndpoint()), 30000, 'browser.connect');
    return holder;
  } catch (error) {
    await close(holder, name);
    throw error;
  }
}
