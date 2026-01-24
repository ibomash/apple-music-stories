const fs = require("fs/promises");
const path = require("path");
const puppeteer = require("puppeteer");

const BASE_URL = process.env.STORY_BASE_URL || "http://127.0.0.1:8000";
const USER_DATA_DIR = process.env.PUPPETEER_USER_DATA_DIR || "";
const SESSION_PATH = process.env.APPLE_MUSIC_SESSION_PATH || "";
const INTERACTIVE = process.env.APPLE_MUSIC_INTERACTIVE === "1";

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

const run = async () => {
  const launchOptions = {
    headless: resolveHeadless(process.env.PUPPETEER_HEADLESS),
  };

  if (USER_DATA_DIR) {
    launchOptions.userDataDir = USER_DATA_DIR;
  }

  const browser = await puppeteer.launch(launchOptions);

  try {
    const page = await browser.newPage();
    const session = await readSession();
    if (session?.cookies?.length) {
      await page.setCookie(...session.cookies);
    }

    if (USER_DATA_DIR) {
      console.log(`Using Puppeteer user data dir: ${USER_DATA_DIR}`);
    }
    await page.goto(BASE_URL, { waitUntil: "networkidle2" });

    const indexTitle = await page.title();
    const firstStoryHref = await page.$eval("a.story-card", (link) =>
      link.getAttribute("href"),
    );

    if (!firstStoryHref) {
      throw new Error("No story cards found on index page.");
    }

    const storyUrl = new URL(firstStoryHref, BASE_URL).toString();
    await page.goto(storyUrl, { waitUntil: "networkidle2" });
    await page.waitForSelector(".hero", { timeout: 5000 });

    if (INTERACTIVE) {
      console.log("Complete Apple Music sign-in in the browser window.");
      await waitForEnter();
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

    console.log("Puppeteer story check ok:");
    console.log(`- Index title: ${indexTitle}`);
    console.log(`- Story URL: ${storyUrl}`);
    console.log(`- Story title: ${storyTitle}`);
    console.log(`- Sections: ${sectionCount}`);
    console.log(`- Media cards: ${mediaCardCount}`);

    await writeSession(await page.cookies());
  } finally {
    await browser.close();
  }
};

run().catch((error) => {
  console.error("Puppeteer story check failed:");
  console.error(error);
  process.exit(1);
});
