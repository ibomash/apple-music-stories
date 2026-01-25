const fs = require("fs/promises");
const path = require("path");
const puppeteer = require("puppeteer");

const BASE_URL = process.env.STORY_BASE_URL || "http://127.0.0.1:8000";
const USER_DATA_DIR = process.env.PUPPETEER_USER_DATA_DIR || "";
const SESSION_PATH = process.env.APPLE_MUSIC_SESSION_PATH || "";
const INTERACTIVE = process.env.APPLE_MUSIC_INTERACTIVE === "1";
const SKIP_PLAYBACK = process.env.APPLE_MUSIC_SKIP_PLAYBACK === "1";
const PLAYBACK_STORY_ID = process.env.APPLE_MUSIC_STORY_ID || "hip-hop-changed-the-game";
const PLAYBACK_MEDIA_KEY = process.env.APPLE_MUSIC_MEDIA_KEY || "trk-alright";

const resolveHeadless = (value) => {
  if (!value) {
    return "new";
  }

  const normalized = value.toLowerCase();
  if (normalized === "false" || normalized === "0") {
    return false;
  }

  if (normalized === "true" || normalized === "1") {
    return true;
  }

  return value;
};

const readSession = async () => {
  if (!SESSION_PATH) {
    return null;
  }

  try {
    const raw = await fs.readFile(SESSION_PATH, "utf8");
    return JSON.parse(raw);
  } catch (error) {
    if (error.code === "ENOENT") {
      return null;
    }

    throw error;
  }
};

const writeSession = async (cookies) => {
  if (!SESSION_PATH) {
    return;
  }

  await fs.mkdir(path.dirname(SESSION_PATH), { recursive: true });
  const payload = {
    savedAt: new Date().toISOString(),
    baseUrl: BASE_URL,
    cookies,
  };
  await fs.writeFile(SESSION_PATH, JSON.stringify(payload, null, 2));
};

const waitForEnter = async () => {
  if (!process.stdin.isTTY) {
    console.log("Interactive mode requested, but no TTY is available.");
    return;
  }

  console.log("Press Enter to continue...");
  await new Promise((resolve) => process.stdin.once("data", resolve));
  process.stdin.pause();
};

const pageLogs = [];
const pageErrors = [];

const run = async () => {
  const launchOptions = {
    headless: resolveHeadless(process.env.PUPPETEER_HEADLESS),
    ignoreHTTPSErrors: true,
    args: ["--ignore-certificate-errors"],
  };

  if (USER_DATA_DIR) {
    launchOptions.userDataDir = USER_DATA_DIR;
  }

  const browser = await puppeteer.launch(launchOptions);

  try {
    const page = await browser.newPage();
    page.on("console", (message) => {
      pageLogs.push(`[${message.type()}] ${message.text()}`);
    });
    page.on("pageerror", (error) => {
      pageErrors.push(`[pageerror] ${error.message}`);
    });

    const session = await readSession();
    if (session?.cookies?.length) {
      await page.setCookie(...session.cookies);
    }

    if (USER_DATA_DIR) {
      console.log(`Using Puppeteer user data dir: ${USER_DATA_DIR}`);
    }
    await page.goto(BASE_URL, { waitUntil: "networkidle2" });

    const indexTitle = await page.title();
    const storySelector = !INTERACTIVE && !SKIP_PLAYBACK
      ? `a.story-card[href="/stories/${PLAYBACK_STORY_ID}"]`
      : "a.story-card";
    const firstStoryHref = await page.$eval(storySelector, (link) =>
      link.getAttribute("href"),
    );

    if (!firstStoryHref) {
      if (!INTERACTIVE && !SKIP_PLAYBACK) {
        throw new Error(
          `Story ${PLAYBACK_STORY_ID} not found on index page.`,
        );
      }
      throw new Error("No story cards found on index page.");
    }

    const storyUrl = new URL(firstStoryHref, BASE_URL).toString();
    await page.goto(storyUrl, { waitUntil: "networkidle2" });
    await page.waitForSelector(".hero", { timeout: 5000 });

    if (INTERACTIVE) {
      console.log("Complete Apple Music sign-in in the browser window.");
      await waitForEnter();
    }

    if (!INTERACTIVE && !SKIP_PLAYBACK) {
      try {
        await page.waitForFunction(
          () => Boolean(window.MusicKit),
          { timeout: 15000 },
        );
      } catch (error) {
        const status = await page.evaluate(() => {
          const statusEl = document.querySelector("[data-auth-status]");
          return {
            message: statusEl ? statusEl.textContent : "",
            secure: window.isSecureContext,
            protocol: window.location.protocol,
          };
        });
        throw new Error(
          `MusicKit JS did not load. Status: ${status.message || ""} Secure: ${status.secure} Protocol: ${status.protocol}.`,
        );
      }

      const instanceReady = await page.evaluate(() => {
        if (!window.MusicKit) {
          return false;
        }
        try {
          return Boolean(window.MusicKit.getInstance());
        } catch (error) {
          return false;
        }
      });
      if (!instanceReady) {
        const status = await page.evaluate(() => {
          const statusEl = document.querySelector("[data-auth-status]");
          return statusEl ? statusEl.textContent : "";
        });
        throw new Error(
          `MusicKit instance is not configured. Status: ${status || ""}`,
        );
      }

      const authButton = await page.$("[data-action=authorize]");
      if (!authButton) {
        throw new Error("Authorize button not found on story page.");
      }

      const isAuthorized = await page.evaluate(() => {
        const instance = window.MusicKit ? window.MusicKit.getInstance() : null;
        return Boolean(instance && instance.isAuthorized);
      });

      if (!isAuthorized) {
        // Set up popup listener for auth flow (MusicKit v3 opens a popup)
        const popupPromise = new Promise((resolve) => {
          browser.once("targetcreated", async (target) => {
            if (target.type() === "page") {
              const popup = await target.page();
              resolve(popup);
            }
          });
          // Timeout if no popup
          setTimeout(() => resolve(null), 10000);
        });

        await authButton.click();

        // Wait for either popup-based auth or direct auth
        const popup = await popupPromise;
        if (popup) {
          console.log("Auth popup opened. Waiting for completion...");
        }

        try {
          await page.waitForFunction(
            () => {
              const instance = window.MusicKit ? window.MusicKit.getInstance() : null;
              return Boolean(instance && instance.isAuthorized);
            },
            { timeout: 30000 },
          );
        } catch (error) {
          throw new Error("Apple Music authorization did not complete. Manual sign-in may be required. Run scripts/musickit_v3_auth.sh first.");
        }
      }
    }

    const storyTitle = await page.$eval(".title", (title) =>
      title.textContent ? title.textContent.trim() : "",
    );
    const sectionCount = await page.$$eval(".section",
      (sections) => sections.length,
    );
    const mediaCardCount = await page.$$eval(
      ".media-card",
      (cards) => cards.length,
    );

    if (!INTERACTIVE && !SKIP_PLAYBACK) {
      const mediaSelector = `.media-card[data-media-key="${PLAYBACK_MEDIA_KEY}"] [data-action=play]`;
      const firstPlayButton = await page.$(mediaSelector);
      if (!firstPlayButton) {
        throw new Error(
          `Play button not found for media key ${PLAYBACK_MEDIA_KEY}.`,
        );
      }

      try {
        await page.waitForFunction(
          (selector) => {
            const button = document.querySelector(selector);
            return Boolean(button && !button.disabled);
          },
          { timeout: 15000 },
          mediaSelector,
        );
      } catch (error) {
        throw new Error("Play button is disabled. Check Apple Music authorization.");
      }

      await firstPlayButton.click();
      await page.waitForFunction(
        () => {
          if (!window.MusicKit) {
            return false;
          }
          const instance = window.MusicKit.getInstance();
          return Boolean(instance && instance.isPlaying);
        },
        { timeout: 15000 },
      );
    }

    console.log("Puppeteer story check ok:");
    console.log(`- Index title: ${indexTitle}`);
    console.log(`- Story URL: ${storyUrl}`);
    console.log(`- Story title: ${storyTitle}`);
    console.log(`- Sections: ${sectionCount}`);
    console.log(`- Media cards: ${mediaCardCount}`);
    if (!INTERACTIVE && !SKIP_PLAYBACK) {
      console.log("- Playback started: true");
    } else {
      console.log("- Playback started: skipped");
    }

    await writeSession(await page.cookies());
  } finally {
    await browser.close();
  }
};

run().catch((error) => {
  console.error("Puppeteer story check failed:");
  console.error(error);
  if (pageErrors.length) {
    console.error("Page errors:");
    pageErrors.forEach((entry) => console.error(entry));
  }
  if (pageLogs.length) {
    console.error("Page console logs:");
    pageLogs.forEach((entry) => console.error(entry));
  }
  process.exit(1);
});
