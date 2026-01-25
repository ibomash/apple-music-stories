/**
 * Puppeteer test for MusicKit JS sample app.
 * 
 * Tests:
 * 1. MusicKit loads and configures
 * 2. Authorization flow works
 * 3. Play/pause controls work
 * 4. Timer ticks during playback
 * 
 * Usage:
 *   node examples/musickit-sample/puppeteer_test.js
 * 
 * Environment variables:
 *   SAMPLE_BASE_URL: Server URL (default: https://127.0.0.1:8443)
 *   PUPPETEER_USER_DATA_DIR: Browser profile dir for persistent auth
 *   PUPPETEER_HEADLESS: false to see the browser
 *   SAMPLE_INTERACTIVE: 1 to pause for manual auth
 */

const puppeteer = require("puppeteer");

const BASE_URL = process.env.SAMPLE_BASE_URL || "https://127.0.0.1:8443";
const USER_DATA_DIR = process.env.PUPPETEER_USER_DATA_DIR || "";
const INTERACTIVE = process.env.SAMPLE_INTERACTIVE === "1";
const HEADLESS = (() => {
  const val = process.env.PUPPETEER_HEADLESS;
  if (!val) return "new";
  if (val === "false" || val === "0") return false;
  if (val === "true" || val === "1") return true;
  return val;
})();

// Helpers
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

const waitForEnter = async () => {
  if (!process.stdin.isTTY) {
    console.log("Interactive mode requested, but no TTY. Continuing...");
    return;
  }
  console.log("Press Enter to continue...");
  await new Promise((r) => process.stdin.once("data", r));
  process.stdin.pause();
};

// Collected logs
const pageLogs = [];
const pageErrors = [];

const run = async () => {
  console.log(`Testing MusicKit sample at ${BASE_URL}`);
  console.log(`Headless: ${HEADLESS}`);
  console.log(`Interactive: ${INTERACTIVE}`);
  
  const launchOptions = {
    headless: HEADLESS,
    ignoreHTTPSErrors: true,
    args: ["--ignore-certificate-errors"],
  };
  
  if (USER_DATA_DIR) {
    launchOptions.userDataDir = USER_DATA_DIR;
    console.log(`User data dir: ${USER_DATA_DIR}`);
  }
  
  const browser = await puppeteer.launch(launchOptions);
  
  try {
    const page = await browser.newPage();
    
    // Capture console and errors
    page.on("console", (msg) => {
      const text = `[${msg.type()}] ${msg.text()}`;
      pageLogs.push(text);
      if (msg.type() === "error") {
        console.log(`  Console: ${text}`);
      }
    });
    page.on("pageerror", (err) => {
      const text = `[pageerror] ${err.message}`;
      pageErrors.push(text);
      console.log(`  Page error: ${err.message}`);
    });
    
    // Navigate to sample
    console.log("\n1. Loading page...");
    await page.goto(BASE_URL, { waitUntil: "networkidle2" });
    
    const title = await page.title();
    console.log(`   Title: ${title}`);
    
    // Wait for MusicKit to load
    console.log("\n2. Waiting for MusicKit to load...");
    try {
      await page.waitForFunction(
        () => typeof MusicKit !== "undefined" && MusicKit.getInstance,
        { timeout: 10000 }
      );
      console.log("   MusicKit loaded");
    } catch (e) {
      throw new Error("MusicKit did not load within 10s");
    }
    
    // Check if configured
    console.log("\n3. Checking MusicKit configuration...");
    const configStatus = await page.evaluate(() => {
      try {
        const music = MusicKit.getInstance();
        return {
          configured: Boolean(music),
          storefront: music?.storefrontId || null,
          authorized: music?.isAuthorized || false,
        };
      } catch (e) {
        return { configured: false, error: e.message };
      }
    });
    
    if (!configStatus.configured) {
      throw new Error(`MusicKit not configured: ${configStatus.error || "unknown"}`);
    }
    console.log(`   Configured: true`);
    console.log(`   Storefront: ${configStatus.storefront}`);
    console.log(`   Authorized: ${configStatus.authorized}`);
    
    // Authorization
    if (!configStatus.authorized) {
      console.log("\n4. Authorizing...");
      
      if (INTERACTIVE) {
        console.log("   Please authorize in the browser window.");
        await waitForEnter();
      } else {
        // Click the authorize button
        await page.click('[data-action="authorize"]');
        
        // Wait for authorization (with popup handling)
        try {
          await page.waitForFunction(
            () => {
              const music = MusicKit.getInstance();
              return music && music.isAuthorized;
            },
            { timeout: 30000 }
          );
          console.log("   Authorized successfully");
        } catch (e) {
          // Check current status
          const status = await page.evaluate(() => {
            const el = document.querySelector('[data-status]');
            return el?.textContent || '';
          });
          throw new Error(`Authorization failed. Status: ${status}`);
        }
      }
    } else {
      console.log("\n4. Already authorized (skipping)");
    }
    
    // Verify authorized state
    const authState = await page.evaluate(() => {
      const music = MusicKit.getInstance();
      return music?.isAuthorized || false;
    });
    
    if (!authState) {
      throw new Error("Not authorized after auth flow");
    }
    
    // Test playback
    console.log("\n5. Testing playback...");
    
    // Click play
    console.log("   Clicking Play...");
    await page.click('[data-action="play"]');
    
    // Wait for playing state (MusicKit v1 uses player.isPlaying)
    try {
      await page.waitForFunction(
        () => {
          const music = MusicKit.getInstance();
          // v1 uses music.player.isPlaying, v3 uses music.isPlaying
          return music && (music.isPlaying || (music.player && music.player.isPlaying));
        },
        { timeout: 15000 }
      );
      console.log("   Playback started");
    } catch (e) {
      // Get diagnostic info
      const diag = await page.evaluate(() => {
        const music = MusicKit.getInstance();
        const player = music?.player;
        return {
          isPlaying: music?.isPlaying,
          playerIsPlaying: player?.isPlaying,
          playbackState: music?.playbackState,
          playerPlaybackState: player?.playbackState,
          nowPlayingItem: music?.nowPlayingItem ? {
            title: music.nowPlayingItem.title,
            id: music.nowPlayingItem.id,
          } : (player?.nowPlayingItem ? {
            title: player.nowPlayingItem.title,
            id: player.nowPlayingItem.id,
          } : null),
          queueLength: player?.queue?.length || music?.queue?.length || 0,
        };
      });
      console.log("   Diagnostics:", JSON.stringify(diag, null, 2));
      throw new Error(`Playback did not start. State: ${diag.playerPlaybackState || diag.playbackState}`);
    }
    
    // Check timer is ticking
    console.log("\n6. Verifying timer ticks...");
    const time1 = await page.evaluate(() => {
      const music = MusicKit.getInstance();
      return music?.currentPlaybackTime || 0;
    });
    console.log(`   Time at check 1: ${time1.toFixed(1)}s`);
    
    await sleep(2000);
    
    const time2 = await page.evaluate(() => {
      const music = MusicKit.getInstance();
      return music?.currentPlaybackTime || 0;
    });
    console.log(`   Time at check 2: ${time2.toFixed(1)}s`);
    
    if (time2 <= time1) {
      throw new Error(`Timer not advancing: ${time1} -> ${time2}`);
    }
    console.log(`   Timer advanced by ${(time2 - time1).toFixed(1)}s`);
    
    // Test pause
    console.log("\n7. Testing pause...");
    await page.click('[data-action="pause"]');
    
    await page.waitForFunction(
      () => {
        const music = MusicKit.getInstance();
        return music && !music.isPlaying;
      },
      { timeout: 5000 }
    );
    console.log("   Paused successfully");
    
    // Test resume
    console.log("\n8. Testing resume...");
    await page.click('[data-action="play"]');
    
    await page.waitForFunction(
      () => {
        const music = MusicKit.getInstance();
        return music && music.isPlaying;
      },
      { timeout: 5000 }
    );
    console.log("   Resumed successfully");
    
    // Clean up - stop playback
    console.log("\n9. Stopping playback...");
    await page.click('[data-action="stop"]');
    await sleep(500);
    
    console.log("\n=== All tests passed ===\n");
    
  } finally {
    await browser.close();
  }
};

run().catch((error) => {
  console.error("\n=== Test failed ===");
  console.error(error.message);
  
  if (pageErrors.length) {
    console.error("\nPage errors:");
    pageErrors.forEach((e) => console.error("  " + e));
  }
  
  if (pageLogs.length) {
    console.error("\nPage console logs (last 20):");
    pageLogs.slice(-20).forEach((l) => console.error("  " + l));
  }
  
  process.exit(1);
});
