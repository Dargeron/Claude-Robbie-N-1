"""Load the packed web build in headless Chromium, wait for the station's [perf] benchmark,
print its timings and any script errors. Exit 1 on a script error or if the page never got there.
Usage: python3 tools/web/check_page.py <url> <screenshot.png>"""
import asyncio, sys, time
from playwright.async_api import async_playwright
async def main():
    async with async_playwright() as p:
        b = await p.chromium.launch(args=["--use-gl=angle", "--use-angle=swiftshader", "--enable-unsafe-swiftshader"])
        page = await b.new_page(viewport={"width": 1280, "height": 720})
        logs = []
        page.on("console", lambda m: logs.append(m.text))
        page.on("pageerror", lambda e: logs.append(f"pageerror: {e}"))
        t0 = time.time()
        await page.goto(sys.argv[1])
        for i in range(110):
            await asyncio.sleep(1)
            if any("[perf] done" in l for l in logs):
                break
        print("elapsed", round(time.time() - t0, 1))
        for l in logs:
            if "[perf]" in l or "error" in l.lower():
                print(l[:200])
        await page.screenshot(path=sys.argv[2])
        await b.close()
        bad = any("SCRIPT ERROR" in l or "Parse Error" in l or "pageerror" in l for l in logs)
        done = any("[perf] done" in l for l in logs)
        print("webcheck:", "ok" if done and not bad else "FAILED")
        sys.exit(0 if done and not bad else 1)
asyncio.run(main())
