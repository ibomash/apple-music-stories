const puppeteer = require("puppeteer");

const BASE_URL = process.env.STORY_BASE_URL || "http://127.0.0.1:8000";

const run = async () => {
  const browser = await puppeteer.launch({
    headless: "new",
  });

  try {
    const page = await browser.newPage();
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
  } finally {
    await browser.close();
  }
};

run().catch((error) => {
  console.error("Puppeteer story check failed:");
  console.error(error);
  process.exit(1);
});
