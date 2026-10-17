# Usage: serve out/site (tools/site.sh) and run: python3 tools/web/playtest.py http://127.0.0.1:PORT/ <shots_dir>
"""A scripted first-time player in a real browser: launch, scrub, change a rule, launch, survey."""
import asyncio, sys, time
from playwright.async_api import async_playwright
OUT = sys.argv[2]
async def main():
    async with async_playwright() as p:
        b = await p.chromium.launch(args=["--use-gl=angle", "--use-angle=swiftshader", "--enable-unsafe-swiftshader"])
        page = await b.new_page(viewport={"width": 1280, "height": 720})
        logs = []
        page.on("console", lambda m: logs.append(m.text))
        page.on("pageerror", lambda e: logs.append(f"pageerror: {e}"))
        await page.goto(sys.argv[1])
        for i in range(60):
            await asyncio.sleep(1)
            if await page.evaluate("document.getElementById('status') === null"):
                break
        await asyncio.sleep(2)
        n = [0]
        async def shot(name):
            n[0] += 1
            await page.screenshot(path=f"{OUT}/{n[0]:02d}-{name}.png")
        await shot("start")
        await page.mouse.click(1150, 335)          # LAUNCH ROBBIE 001
        await asyncio.sleep(4)
        await shot("launched")
        await page.mouse.move(300, 433)             # drag along the timeline
        await page.mouse.down()
        await page.mouse.move(450, 433, steps=10)
        await page.mouse.up()
        await asyncio.sleep(1)
        await shot("scrubbed")
        await page.mouse.click(825, 111)            # rule 1's order dropdown
        await asyncio.sleep(1)
        await shot("dropdown")
        await page.mouse.click(774, 214)            # "Follow wall" in the open list
        await asyncio.sleep(1)
        await shot("follow-wall")
        await page.mouse.click(1150, 335)           # LAUNCH ROBBIE 002
        await asyncio.sleep(12)
        await shot("second-robbie")
        await page.mouse.click(970, 447)            # SEND THE SURVEY FLEET
        await asyncio.sleep(6)
        await shot("survey-running")
        await asyncio.sleep(12)
        await shot("survey-done")
        bad = [l for l in logs if "ERROR" in l or "pageerror" in l]
        print("errors:", bad[:5])
        await b.close()
asyncio.run(main())
