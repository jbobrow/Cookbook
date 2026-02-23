#!/usr/bin/env python3
"""
Test harness for RecipeURLImporter's HTML direction parsing.

Mirrors the regex logic from RecipeURLImporter.swift so we can iterate
quickly without building the full iOS app.

Usage:
    python3 Scripts/test_parser.py                  # run against built-in test HTML
    python3 Scripts/test_parser.py <url>            # fetch a URL and parse it
    python3 Scripts/test_parser.py --file page.html # parse a local HTML file
"""

import re
import sys
import html as html_module
import textwrap

# ---------------------------------------------------------------------------
# Port of RecipeURLImporter's parsing helpers
# ---------------------------------------------------------------------------

def strip_html(string: str) -> str:
    """Port of RecipeURLImporter.stripHTML(_:)"""
    result = re.sub(r"<[^>]+>", "", string)

    # Decode numeric HTML entities (hex)
    def replace_hex(m):
        cp = int(m.group(1), 16)
        return chr(cp)
    result = re.sub(r"&#x([0-9a-fA-F]+);", replace_hex, result)

    # Decode numeric HTML entities (decimal)
    def replace_dec(m):
        cp = int(m.group(1))
        return chr(cp)
    result = re.sub(r"&#(\d+);", replace_dec, result)

    # Named entities
    replacements = {
        "&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": '"',
        "&apos;": "'", "&nbsp;": " ", "&ndash;": "\u2013",
        "&mdash;": "\u2014", "&lsquo;": "\u2018", "&rsquo;": "\u2019",
        "&ldquo;": "\u201C", "&rdquo;": "\u201D", "&bull;": "\u2022",
        "&deg;": "\u00B0", "&frac12;": "\u00BD", "&frac13;": "\u2153",
        "&frac14;": "\u00BC", "&frac34;": "\u00BE",
    }
    for entity, char in replacements.items():
        result = result.replace(entity, char)

    result = result.replace("\u00A0", " ")
    return result.strip()


def extract_steps_from_html_block(html: str, pattern: str) -> list[str] | None:
    """Port of RecipeURLImporter.extractStepsFromHTMLBlock(html:pattern:)"""
    matches = list(re.finditer(pattern, html, re.IGNORECASE | re.DOTALL))

    all_results = []
    for match in matches:
        content = match.group(1)
        item_pattern = r"<(?:li|p)[^>]*>([\s\S]*?)</(?:li|p)>"
        item_matches = re.finditer(item_pattern, content, re.IGNORECASE | re.DOTALL)
        for item_match in item_matches:
            raw_content = item_match.group(1)
            # Skip group wrapper items that contain nested lists
            if re.search(r"<(?:ol|ul)\b", raw_content):
                continue
            text = strip_html(raw_content)
            if text and len(text) > 15:
                all_results.append(text)

    return all_results if all_results else None


def parse_directions_from_html(html: str, verbose: bool = False) -> list[str]:
    """Port of RecipeURLImporter.parseDirectionsFromHTML(html:)"""

    # Strategy 1: itemprop="recipeInstructions" container (Microdata)
    if verbose:
        print("\n--- Strategy 1: itemprop Microdata ---")
    itemprop_pattern = r'''itemprop\s*=\s*["']recipeInstructions["'][^>]*>([\s\S]*?)</(?:ol|ul|div|section)>'''
    directions = extract_steps_from_html_block(html, itemprop_pattern)
    if directions:
        if verbose:
            print(f"  MATCHED: {len(directions)} steps")
            for i, d in enumerate(directions, 1):
                print(f"  {i}. {d[:80]}{'...' if len(d) > 80 else ''}")
        return directions
    elif verbose:
        print("  No match.")

    # Strategy 2: <p> inside step content containers (handles deep nesting)
    if verbose:
        print("\n--- Strategy 2: Step content divs ---")
    step_content_pattern = r'''<div[^>]*class\s*=\s*["'][^"']*(?:stepContent|step_content|instruction_content)[^"']*["'][^>]*>([\s\S]*?)</div>'''
    content_directions = []
    for match in re.finditer(step_content_pattern, html, re.IGNORECASE | re.DOTALL):
        step = strip_html(match.group(1))
        if step and len(step) > 15:
            content_directions.append(step)
    if content_directions:
        if verbose:
            print(f"  MATCHED: {len(content_directions)} steps")
            for i, d in enumerate(content_directions, 1):
                print(f"  {i}. {d[:80]}{'...' if len(d) > 80 else ''}")
        return content_directions
    elif verbose:
        print("  No match.")

    # Strategy 3: containers with step/instruction/preparation class names
    if verbose:
        print("\n--- Strategy 3: Class-based containers ---")
    class_pattern = r'''<(?:ol|ul|div|section)[^>]*class\s*=\s*["'][^"']*(?:preparation_step|instruction|step_content|recipe-steps|recipe_steps|steps_list)[^"']*["'][^>]*>([\s\S]*?)</(?:ol|ul|div|section)>'''
    directions = extract_steps_from_html_block(html, class_pattern)
    if directions:
        if verbose:
            print(f"  MATCHED: {len(directions)} steps")
            for i, d in enumerate(directions, 1):
                print(f"  {i}. {d[:80]}{'...' if len(d) > 80 else ''}")
        return directions
    elif verbose:
        print("  No match.")

    # Strategy 4: Individual elements with step-related class names
    if verbose:
        print("\n--- Strategy 4: Individual step elements ---")
    directions = []
    step_pattern = r'''<(?:li|p)[^>]*class\s*=\s*["'][^"']*(?:step_text|step_content|instruction_text|preparation_step)[^"']*["'][^>]*>([\s\S]*?)</(?:li|p)>'''
    for match in re.finditer(step_pattern, html, re.IGNORECASE | re.DOTALL):
        step = strip_html(match.group(1))
        if step and len(step) > 15:
            directions.append(step)
    if verbose:
        if directions:
            print(f"  MATCHED: {len(directions)} steps")
            for i, d in enumerate(directions, 1):
                print(f"  {i}. {d[:80]}{'...' if len(d) > 80 else ''}")
        else:
            print("  No match.")

    return directions


# ---------------------------------------------------------------------------
# Test HTML samples
# ---------------------------------------------------------------------------

NYT_COOKING_HTML = '''<ol class="preparation_stepList___jqWa"><li><h3 class="pantry--label preparation_stepGroupName__vQuRQ">Prepare the Cabbage:</h3><ol class="preparation_stepList___jqWa"><li class="preparation_step__nzZHP" id="recipe-step-1"><div class="pantry--ui-lg-strong preparation_stepNumber__qWIz4">Step <!-- -->1</div><div class="preparation_stepContent__CFrQM"><p class="pantry--body-long">Cut the cabbage half lengthwise through the core to get four wedges.</p></div></li><li class="preparation_step__nzZHP" id="recipe-step-2"><div class="pantry--ui-lg-strong preparation_stepNumber__qWIz4">Step <!-- -->2</div><div class="preparation_stepContent__CFrQM"><p class="pantry--body-long">Heat a large well-seasoned cast-iron skillet or heavy-bottomed pan for which you have a lid over medium-high. Add 2 tablespoons of the olive oil. Once shimmering, add the cabbage, cut sides down, and season with \u00bd teaspoon of the salt. Using tongs, move the wedges back and forth gently to ensure they\u2019re evenly coated in the oil, and cook until browned on the bottom, 5 to 7 minutes. Carefully flip, sprinkle with the remaining \u00bd teaspoon salt, and cook until browned on the other side, 5 to 7 minutes. Transfer the wedges to a plate. Take the pan off the heat to cool for 5 to 10 minutes (do some prep or cleanup in the meantime).</p></div></li><li class="preparation_step__nzZHP" id="recipe-step-3"><div class="pantry--ui-lg-strong preparation_stepNumber__qWIz4">Step <!-- -->3</div><div class="preparation_stepContent__CFrQM"><p class="pantry--body-long">Stir the maple syrup into the canned tomatoes. Set aside.</p></div></li><li class="preparation_step__nzZHP" id="recipe-step-4"><div class="pantry--ui-lg-strong preparation_stepNumber__qWIz4">Step <!-- -->4</div><div class="preparation_stepContent__CFrQM"><p class="pantry--body-long">Heat the remaining 1 tablespoon oil in the same pan over medium heat. Add the cumin seeds and cook, tossing frequently, until they are aromatic and darker in color, 1 minute. Add the shallots and garlic and cook for 2 minutes, until the shallots starts to soften. Add the paprika, coriander, cinnamon, nutmeg and Aleppo pepper and cook for 1 minute, stirring frequently. If needed, add a drizzle of oil if things seem dry.&nbsp;</p></div></li><li class="preparation_step__nzZHP" id="recipe-step-5"><div class="pantry--ui-lg-strong preparation_stepNumber__qWIz4">Step <!-- -->5</div><div class="preparation_stepContent__CFrQM"><p class="pantry--body-long">Reduce the heat to medium-low. Pour in the tomato mixture with all the juices, stir, and carefully nestle the wedges back into the pan. Cover and simmer until the cabbage is tender and the tomatoes have thickened a bit, 8 to 10 minutes, opening the lid once to check if the tomatoes are drying up (if so, add a few splashes of water).</p></div></li></ol></li><li><h3 class="pantry--label preparation_stepGroupName__vQuRQ">Make the tahini sauce while the cabbage is simmering:</h3><ol class="preparation_stepList___jqWa"><li class="preparation_step__nzZHP" id="recipe-step-6"><div class="pantry--ui-lg-strong preparation_stepNumber__qWIz4">Step <!-- -->6</div><div class="preparation_stepContent__CFrQM"><p class="pantry--body-long">In a medium bowl, whisk together the tahini, lemon juice, maple syrup, garlic, cumin, salt and pepper to taste. Add the ice water a tablespoon at a time, whisking as you go. It will get stiff at first but eventually will become creamy yet pourable. Taste for seasonings, adding more salt as desired.</p></div></li></ol></li><li><h3 class="pantry--label preparation_stepGroupName__vQuRQ">To serve:</h3><ol class="preparation_stepList___jqWa"><li class="preparation_step__nzZHP" id="recipe-step-7"><div class="pantry--ui-lg-strong preparation_stepNumber__qWIz4">Step <!-- -->7</div><div class="preparation_stepContent__CFrQM"><p class="pantry--body-long">Serve the cabbage straight from the pan. Top with cilantro and a squeeze of lemon juice. Spoon some tahini sauce generously on top and serve more on the side.</p></div></li></ol></li><li><h3 class="pantry--label preparation_stepGroupName__vQuRQ"></h3><ol class="preparation_stepList___jqWa"></ol></li></ol>'''


def run_test(name: str, html: str):
    print(f"\n{'='*70}")
    print(f"TEST: {name}")
    print(f"{'='*70}")

    directions = parse_directions_from_html(html, verbose=True)

    print(f"\n--- FINAL RESULT: {len(directions)} steps ---")
    for i, d in enumerate(directions, 1):
        print(f"\n  Step {i}:")
        print(textwrap.fill(d, width=76, initial_indent="    ", subsequent_indent="    "))

    return directions


def fetch_and_parse(url: str):
    import urllib.request
    print(f"\nFetching {url}...")
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req) as resp:
        html = resp.read().decode("utf-8", errors="replace")
    print(f"Fetched {len(html)} bytes.")

    # Show JSON-LD directions if present (to see what the primary parser gets)
    ld_pattern = r'<script[^>]*type\s*=\s*["\']?application/ld\+json["\']?[^>]*>([\s\S]*?)</script>'
    import json
    for m in re.finditer(ld_pattern, html, re.IGNORECASE):
        try:
            data = json.loads(m.group(1))
            recipes = []
            if isinstance(data, dict):
                if data.get("@type") == "Recipe":
                    recipes.append(data)
                for item in (data.get("@graph") or []):
                    if isinstance(item, dict) and item.get("@type") == "Recipe":
                        recipes.append(item)
            elif isinstance(data, list):
                for item in data:
                    if isinstance(item, dict) and item.get("@type") == "Recipe":
                        recipes.append(item)
            for recipe in recipes:
                instructions = recipe.get("recipeInstructions", [])
                print(f"\n--- JSON-LD: {len(instructions)} instruction entries ---")
                for i, inst in enumerate(instructions):
                    if isinstance(inst, str):
                        print(f"  {i+1}. [string] {inst[:80]}...")
                    elif isinstance(inst, dict):
                        t = inst.get("@type", "?")
                        text = inst.get("text", inst.get("name", ""))[:60]
                        items = inst.get("itemListElement", [])
                        print(f"  {i+1}. [{t}] text={text!r}... ({len(items)} sub-items)")
        except json.JSONDecodeError:
            pass

    run_test(f"URL: {url}", html)


def extract_json_ld_directions(html: str) -> list[str]:
    """Port of the JSON-LD recipeInstructions extraction path."""
    import json
    ld_pattern = r'<script[^>]*type\s*=\s*["\']?application/ld\+json["\']?[^>]*>([\s\S]*?)</script>'
    for m in re.finditer(ld_pattern, html, re.IGNORECASE):
        try:
            data = json.loads(m.group(1))
        except json.JSONDecodeError:
            continue

        candidates = []
        if isinstance(data, dict):
            candidates.append(data)
            for item in (data.get("@graph") or []):
                if isinstance(item, dict):
                    candidates.append(item)
        elif isinstance(data, list):
            for item in data:
                if isinstance(item, dict):
                    candidates.append(item)
                    for gi in (item.get("@graph") or []):
                        if isinstance(gi, dict):
                            candidates.append(gi)

        for d in candidates:
            dtype = d.get("@type")
            is_recipe = dtype == "Recipe" or (isinstance(dtype, list) and "Recipe" in dtype)
            if not is_recipe:
                continue

            instructions = d.get("recipeInstructions", [])
            directions = []
            if isinstance(instructions, list) and all(isinstance(s, str) for s in instructions):
                directions = instructions
            elif isinstance(instructions, list):
                for step in instructions:
                    if not isinstance(step, dict):
                        continue
                    step_type = step.get("@type", "")
                    if step_type == "HowToSection":
                        for item in (step.get("itemListElement") or []):
                            if isinstance(item, dict):
                                t = item.get("text") or item.get("name") or ""
                                if t:
                                    directions.append(t)
                    elif step.get("text"):
                        directions.append(step["text"])
                    elif step.get("itemListElement"):
                        for item in step["itemListElement"]:
                            if isinstance(item, dict):
                                t = item.get("text") or item.get("name") or ""
                                if t:
                                    directions.append(t)
                    elif step.get("name"):
                        directions.append(step["name"])
            elif isinstance(instructions, str):
                text = re.sub(r"</(?:p|li|div|br\s*/?)>", "\n", instructions)
                text = re.sub(r"<br\s*/?>", "\n", text)
                text = strip_html(text)
                directions = [l.strip() for l in text.split("\n") if l.strip()]

            if directions:
                return [strip_html(d) for d in directions]
    return []


def full_parse(html: str, source_url: str = "test", verbose: bool = False):
    """Port of the full importRecipe logic (JSON-LD + HTML fallback)."""
    json_ld_directions = extract_json_ld_directions(html)
    if verbose:
        print(f"\n--- JSON-LD extracted {len(json_ld_directions)} directions ---")
        for i, d in enumerate(json_ld_directions, 1):
            print(f"  {i}. {d[:80]}{'...' if len(d) > 80 else ''}")

    # Mirror the Swift logic: if JSON-LD got >1 step, use those; otherwise try HTML fallback
    if json_ld_directions and len(json_ld_directions) > 1:
        if verbose:
            print("  -> Using JSON-LD directions (>1 step found).")
        return json_ld_directions

    html_directions = parse_directions_from_html(html, verbose=verbose)

    if json_ld_directions and len(json_ld_directions) <= 1:
        if len(html_directions) > len(json_ld_directions):
            if verbose:
                print(f"  -> JSON-LD had {len(json_ld_directions)} step(s), HTML fallback found {len(html_directions)}. Using HTML.")
            return html_directions
        return json_ld_directions

    return html_directions


def check_results(result: list[str], expected: int, test_name: str):
    print(f"\n{'='*70}")
    if len(result) == expected:
        print(f"PASS [{test_name}]: Got {expected} steps as expected.")
    else:
        print(f"FAIL [{test_name}]: Expected {expected} steps, got {len(result)}.")

    # Verify no step contains "Step N" prefix junk
    prefixed = [s for s in result if re.match(r"^Step\s+\d", s)]
    if prefixed:
        print(f"WARNING: {len(prefixed)} steps have 'Step N' prefix (should be clean):")
        for s in prefixed:
            print(f"  '{s[:60]}...'")
    else:
        print(f"PASS [{test_name}]: No steps have 'Step N' prefix junk.")


if __name__ == "__main__":
    if len(sys.argv) > 1:
        arg = sys.argv[1]
        if arg == "--file":
            with open(sys.argv[2]) as f:
                html = f.read()
            print("=== HTML-only parse ===")
            run_test(f"File: {sys.argv[2]}", html)
            print("\n=== Full parse (JSON-LD + HTML fallback) ===")
            result = full_parse(html, verbose=True)
            print(f"\n--- FULL PARSE RESULT: {len(result)} steps ---")
            for i, d in enumerate(result, 1):
                print(f"\n  Step {i}:")
                print(textwrap.fill(d, width=76, initial_indent="    ", subsequent_indent="    "))
        elif arg.startswith("http"):
            fetch_and_parse(arg)
        else:
            print(f"Unknown argument: {arg}")
            print(__doc__)
    else:
        # Run built-in test against the HTML snippet (no JSON-LD present)
        result = run_test("NYT Cooking (nested grouped steps)", NYT_COOKING_HTML)
        check_results(result, 7, "NYT Cooking HTML")
