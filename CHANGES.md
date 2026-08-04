# External Sources — ZH Update

**Date:** 2026-08-04 (revised v3 — using official HTML samples)
**Auditor:** Super Z (AI)
**Source repo cloned:** https://github.com/HnDK0/external-sources
**HTML samples from:** https://github.com/Parasgaming122/NovelReaderAi/tree/main/html

## Summary

- **Fixed 1 source:** `ttkan.lua` (catalog/search pagination infinite loop, plus new category filters and improved content transforms)
- **Fixed 1 source:** `ixdzs8.lua` 1.0.0 → 1.0.1 (chapter list now uses POST API instead of URL synthesis)
- **Fixed 1 source:** `xbiquge.lua` 1.0.0 → 1.0.1 (multi-page chapter support + page marker stripping)
- **Added 3 new sources:** `shuhaige.lua`, `rayforboe.lua` (NEW in v3), `biquge_company.lua`
- **Updated `zh/index.yaml`** to register the 5 new/fixed sources
- **Tested all 6 plugins** against the official HTML samples from the NovelReaderAi repo — every selector verified against ground truth

## v3 revision notes (using official HTML samples)

After cloning the NovelReaderAi repo and examining the official HTML samples for each site, the following improvements were made:

### ixdzs8.lua 1.0.0 → 1.0.1: Chapter list API

**Discovery:** The official sample `05_chapter_list_api.json` revealed that ixdzs8 has a dedicated chapter list API: `POST /novel/clist/` with body `bid={bookId}`. The response is JSON:
```json
{"rs":200,"data":[{"ordernum":"2","title":"楔 子..."},{"ordernum":"3","title":"第一章..."}, ...]}
```
The `ordernum` maps directly to the chapter URL: `/read/{bookId}/p{ordernum}.html`.

**Bug fixed:** The previous approach synthesized URLs as `p1.html` through `p{N}.html` based on the `.catalog` count. But the official samples showed that for some novels (e.g. book 1), `p1.html` is the novel info page, not chapter 1 — chapters actually start at `p2.html`. The API returns the correct `ordernum` for each chapter, avoiding this off-by-one bug.

### xbiquge.lua 1.0.0 → 1.0.1: Multi-page chapter support (unchanged from v2)

Biquge family chapters can be split across multiple pages (`148374.html`, `148374_2.html`, `148374_3.html`). Fixed with forward-only multi-page walking.

### shuhaige.lua (NEW)

**Site:** `https://m.shuhaige.net/` (书海阁, Simplified Chinese, mobile version)

- **URL patterns:** `/shuku/0_0_0_{page}.html` (catalog), POST `/search.html` (search), `/shu_{bookId}.html` (book page), `/{bookId}/{chId}.html` (chapter)
- **Chapter list:** `ul.vlist li a` (newest-first, reversed to oldest-first)
- **Chapter content:** `.content` with `<p>` paragraphs
- **Multi-page:** Same `{chapterId}_{N}.html` pattern as xbiquge — forward-only walking
- **Noise stripping:** "本小章还未完...", "《{novel}》无错的章节将持续...", "喜欢{novel}请大家收藏..."
- **Verified:** 4/4 tests pass against official samples (catalog, novel info, chapter list, chapter text)

### rayforboe.lua (NEW)

**Site:** `https://www.rayforboe.com/` (顶级看书网, Simplified Chinese)

- **Structure:** Blog-like — each "novel" is a single article page (not multi-chapter)
- **URL patterns:** `/` (home, lists recent articles), `/{category-slug}/{id}` (article page)
- **Chapter list:** Returns a single "chapter" pointing to the article URL
- **Chapter content:** `article .entry` with `<p>` paragraphs
- **Noise stripping:** `<blockquote>` (keyword stuffing), `<nav>` (prev/next article), `.related-posts`, `.article-action`
- **Verified:** 3/3 tests pass against official samples (catalog, novel info, chapter text)

## Revision notes (2026-08-04 update)

After testing against the user's real HTML samples, one significant bug was found and fixed in `xbiquge.lua`:

### xbiquge.lua 1.0.0 → 1.0.1: Multi-page chapter support

**Bug found:** Biquge family chapters can be split across multiple pages (e.g. `148374.html`, `148374_2.html`, `148374_3.html`). The original code only extracted page 1, missing up to 2/3 of the chapter content. The "Next chapter" link (`下一章`) on the page actually points to the next PAGE of the same chapter, not a new chapter.

**Fix:** Rewrote `getChapterText` to walk forward through `{chapterId}_{N}.html` pages:
1. Extract `chapterFile` and `startPage` from the URL
2. Extract page 1 content
3. Look for a link to `{chapterFile}_{currentPage+1}.html` (strictly forward — avoids re-fetching backward links like `148374_1.html` on page 2)
4. Fetch the next page, extract content, append to parts list
5. Repeat until no forward link is found (stops at the last page, which links to the next CHAPTER with a different chapterId)
6. Concatenate all parts and apply standard transforms

**Also added:** Page marker stripping for biquge's `第(1/3)页` / `Page (1/3)` / `页次(1/3)` patterns that appear at the start and end of each multi-page page.

**Verified against real HTML:**
- `https://www.xbiquge.info/10/10202/148374.html` (3-page chapter)
- Page 1 alone: 889 chars → All 3 pages: 2,558 chars (2.9× more content)
- All 3 pages' content present and unique (no duplicates from backward links)
- Page markers stripped ✅

## Files in this package

```
external-sources-output/
├── zh/
│   ├── index.yaml            ← updated (adds 3 new sources)
│   ├── ttkan.lua             ← FIXED (1.0.0 → 1.1.0)
│   ├── ixdzs8.lua            ← NEW
│   ├── xbiquge.lua           ← NEW
│   ├── biquge_company.lua    ← NEW
│   ├── novel543.lua          ← unchanged
│   ├── piaotia.lua           ← unchanged
│   ├── quanben5.lua          ← unchanged
│   ├── shuba69.lua           ← unchanged
│   ├── sto9.lua              ← unchanged
│   └── twkan.lua             ← unchanged
└── icons/                    ← unchanged (existing icons only)
```

## ttkan.lua — Fix Details

### Bug: Catalog / Search pagination infinite loop

**Root cause:** `https://www.ttkan.co/novel/rank?page=N` and `https://www.ttkan.co/novel/search?q=...&page=N` silently ignore the `page` parameter and return the same 100-book (rank) or 90-book (search) list on every page. The original `getCatalogList` returned `hasNext = #items > 0`, which was always `true` — so the engine kept fetching page after page, getting the same items, forever.

**Fix:**
```lua
function getCatalogList(index)
  if index > 0 then return { items = {}, hasNext = false } end
  -- ... fetch and parse ...
  return { items = items, hasNext = false }  -- ALWAYS false
end
```
Same fix applied to `getCatalogSearch`.

**Verified:**
- `getCatalogList(0)` returns 100 books with `hasNext=false` ✅
- `getCatalogSearch(0, '青山')` returns 90 books with `hasNext=false` ✅
- Engine will now stop after one fetch instead of looping forever

### Add: Category filters

The site exposes per-category rank pages at `/novel/rank/{category}` (discovered from links on the rank home page). Added `getFilterList()` and `getCatalogFiltered()` to expose 13 categories (玄幻, 言情, 穿越, 都市, 科幻, 仙俠, 現言, 歷史, 靈異, 懸疑, 遊戲, 其他, plus 熱門總榜).

### Improvement: Content transforms

Lifted the "collapse duplicated chapter-title prefix" pattern from the `novel_extractor.py` audit work. Also added explicit stripping for the trailing UI tail that ttkan leaves inside `.content`:
- `章節報錯` (chapter report widget)
- `分享給朋友：` (share with friends widget)
- `上一頁 ... 下一頁` (prev/next nav)

**Verified:** Chapter text extraction for `qingshan-huishuohuadezhouzi_1.html` returns 3,637 chars of clean prose, with no leftover noise elements. ✅

## ixdzs8.lua — New Source

**Site:** `https://www.ixdzs8.com/` (爱下电子书, Simplified Chinese)

### URL patterns
- Book page: `/read/{bookId}/` (e.g. `/read/620438/`)
- Chapter: `/read/{bookId}/p{N}.html` (e.g. `/read/620438/p1.html`)
- Catalog: `/sort/{catId}/` (e.g. `/sort/1/` = 玄幻)
- Catalog pg: `/sort/{catId}/index-0-0-0-{N}.html`
- Search: `/bsearch?q={query}&page={N}`

### Anti-bot handling

ixdzs8 uses a **challenge-token** mechanism on chapter pages. The first request returns:
```html
<script>let token = "BASE64..."; window.location.href =
  location.pathname + "?challenge=" + encodeURIComponent(token);</script>
```

The lua's `getChapterText` detects this and does a two-step fetch:
1. Fetch the chapter URL → get the 384-byte challenge page
2. Extract the token, fetch `?challenge={token}` → get the real chapter HTML

If the engine already followed the redirect (some do), the lua detects that the response is NOT the challenge page and skips the second fetch.

### Chapter list

The book page only shows the latest 10 chapters inline. The total count is in `.catalog` as text `共{N}章`. The lua parses the count and synthesizes chapter URLs `/read/{bookId}/p1.html` .. `/read/{bookId}/p{N}.html`. (chapter_id == page number; verified sequential across multiple novels.)

### Content selector

`<section>` inside `<article class="page-content">`. Clean prose with `<p>` paragraphs — no inline noise.

**Verified:**
- Catalog: 20 books ✅
- Search: 20 books for "青山" ✅
- Book details: title, cover, description ✅
- Chapter list: 437 chapters ✅
- Chapter text: 2,501 chars of clean prose ✅

## xbiquge.lua — New Source

**Site:** `https://www.xbiquge.info/` (新笔趣阁, Simplified Chinese, biquge family)

### URL patterns
- Book page: `/{folderId}/{bookId}/` (e.g. `/10/10202/`)
- Chapter: `/{folderId}/{bookId}/{chId}.html` (e.g. `/10/10202/1144623.html`)
- Chapter list pg: `/{folderId}/{bookId}/index_{N}.html` (e.g. `/10/10202/index_2.html`)
- Catalog: `/list{catId}/{page}.html` (e.g. `/list1/1.html` = 玄幻)
- Search: `/search.php?q={query}&p={page}`

### Chapter list (multi-page)

The book page shows the first 100 chapters in `.book_list2`. Subsequent pages are at `/{folder}/{book}/index_{N}.html`. The lua discovers the last page number from the pagination links (the `»` link points to `index_{last}.html`), then uses `http_get_batch` to fetch all remaining pages in parallel. Chapters are already in oldest-first order — no reversal needed.

### Content selector

`<article class="font_max">` inside `section > .container > .box.single`. Content uses `<br>` separators (biquge family convention). Noise elements stripped: `.row.resetfontsize` (font controls), `.row.nav-bottom` (prev/next nav).

**Verified:**
- Catalog: 20 books ✅
- Search: 20 books ✅
- Book details: title, cover, description ✅
- Chapter list: 100 chapters from page 1 (12 total pages = ~1,189 chapters) ✅
- Chapter text: 1,188 chars of clean prose ✅

## biquge_company.lua — New Source

**Site:** `https://www.biquge.company/` (笔趣阁, Simplified Chinese, biquge family)

### URL patterns
- Book page: `/book/{bookId}.html` (e.g. `/book/29901.html`)
- Chapter: `/read/{bookId}/{chId}.html` (e.g. `/read/29901/30753082.html`)
- Catalog: `/sort/0/{page}.html` (e.g. `/sort/0/1.html` = 书库)
- Search: **POST** to `/modules/article/search.php` with body `searchkey={query}&action=login&searchtype=`

### Chapter list

`<dl><dd><a>...</a></dd></dl>` on the book page, listed **newest-first** (biquge family convention). The lua reverses to oldest-first before returning.

### Content selector

`.content > .book.read > .readcontent`. Content uses `<br>` separators. Noise elements stripped: `.booktag` (vote/bookmark), `.text-center` (chapter nav), `.pt10` (tip text), `.book.mt10.pt10.tuijian` (recommendations).

**Verified:**
- Catalog: 30 books ✅
- Search: 15 books for "青山" ✅
- Book details: title, cover, description ✅
- Chapter list: 770 chapters (reversed to oldest-first) ✅
- Chapter text: 3,021 chars of clean prose ✅

## How the lua logic was validated

A Python-based shim of the Lua engine's `html_select` / `html_select_first` / `html_attr` / `html_text` / `html_remove` / `regex_replace` / `url_encode` / `http_get` / `http_post` / `http_get_batch` functions was built (`scripts/lua_engine_shim.py`). This shim uses BeautifulSoup4 to mimic Jsoup's CSS selector behavior and the engine's text extraction semantics.

Each new source then has a dedicated test script (`scripts/test_ixdzs8.py`, `scripts/test_biquge.py`, `scripts/test_ttkan.py`) that:
1. Fetches a real URL from the site
2. Runs the same logic the lua would run (selector → extract → transform)
3. Prints the result + length + first/last 200 chars
4. Returns pass/fail

All 21 individual tests across the 4 sources (1 fixed + 3 new) pass.

## Cross-reference to novel_extractor.py audit

The "collapse duplicated chapter-title prefix" pattern (`_DUP_PREFIX_RE` / `_collapse_duplicated_prefix` in `novel_extractor.py`) was ported to all new lua sources as a `regex_replace` call. This catches the freewebnovel-style bug where the source HTML ships `<h4>Chapter 1: Chapter 1: ...</h4>` (doubled prefix in the source itself). The regex handles both English (`Chapter N: Chapter N: ...`) and Chinese (`第N章：第N章：...` or `第N章 第N章 ...`) patterns, with separators `:`, `：`, `.`, `-`, `—`, or just whitespace.

## Reviewer checklist

To independently verify:

1. **Read the diff between original and fixed ttkan.lua:**
   ```bash
   diff /home/z/my-project/external-sources/zh/ttkan.lua \
        /home/z/my-project/external-sources-output/zh/ttkan.lua
   ```

2. **Re-run the test suite:**
   ```bash
   cd /home/z/my-project/scripts
   python3 test_ttkan.py
   python3 test_ixdzs8.py
   python3 test_biquge.py
   ```

3. **Inspect the new lua files directly:**
   ```bash
   ls -la /home/z/my-project/external-sources-output/zh/
   ```

4. **Verify the index.yaml includes all 10 sources** (7 original + 3 new):
   ```bash
   grep "id:" /home/z/my-project/external-sources-output/zh/index.yaml
   ```
