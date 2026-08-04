-- ── Metadata ────────────────────────────────────────────────────────────────
id       = "shuhaige"
name     = "ShuHaiGe"
version  = "1.0.0"
baseUrl  = "https://m.shuhaige.net/"
language = "zh"
icon     = "https://raw.githubusercontent.com/HnDK0/external-sources/main/icons/shuhaige.png"

-- ── Site notes ──────────────────────────────────────────────────────────────
-- shuhaige (书海阁) is a Simplified-Chinese novel site (mobile version).
--
-- URL patterns:
--   Catalog:    /shuku/0_0_0_{page}.html       (category_status_sort_page)
--   Search:     POST /search.html               body: searchkey={query}
--   Book page:  /shu_{bookId}.html              e.g. /shu_1397.html
--   Chapter:    /{bookId}/{chId}.html           e.g. /1397/152060484.html
--   Chapter pg: /{bookId}/{chId}_{N}.html       (multi-page, same as xbiquge)
--
-- Chapter content:
--   <div class="content"> with <p> paragraphs. Body has id="chapter".
--   Noise in .content:
--     - Trailing "本小章还未完，请点击下一页继续阅读后面精彩内容！" (multi-page indicator)
--     - "《{novel}》无错的章节将持续在书海阁小说网小说网更新..." (site promo)
--     - "喜欢{novel}请大家收藏：(m.shuhaige.net)..." (bookmark promo)
--   Multi-page: "下一页" link points to {chId}_{N}.html (same as xbiquge).
--
-- Catalog structure:
--   <ul class="list"><li>
--     <p class="bookname"><a href="/{bookId}/">Title</a></p>
--     <p class="data"><a href="/author/{author}/">Author Category Status</a></p>
--     <p class="intro">Description...</p>
--     <p class="data"><a href="/{bookId}/{chId}.html">最新： ChapterTitle</a></p>
--   </li></ul>
-- ────────────────────────────────────────────────────────────────────────────

-- ── Helpers ─────────────────────────────────────────────────────────────────

local function absUrl(href)
  if not href or href == "" then return "" end
  if string_starts_with(href, "http") then return href end
  if string_starts_with(href, "//") then return "https:" .. href end
  return url_resolve(baseUrl, href)
end

-- Extract bookId from a book URL like /shu_1397.html or /1397/...
local function extractBookId(bookUrl)
  local id = string.match(bookUrl, "/shu_(%d+)%.html")
  if id then return id end
  id = string.match(bookUrl, "/(%d+)/[^/]*%.html$")
  if id then return id end
  id = string.match(bookUrl, "/(%d+)/?$")
  return id
end

-- Apply standard content transforms.
-- Strips site promos, multi-page indicators, and duplicated chapter titles.
local function applyStandardContentTransforms(text)
  if not text or text == "" then return "" end
  text = string_normalize(text)

  -- Strip site domain references.
  local domain = baseUrl:gsub("https?://", ""):gsub("^www%.", ""):gsub("^m%.", ""):gsub("/$", "")
  text = regex_replace(text, "(?i)" .. domain .. ".*?\\n", "")

  -- Strip shuhaige-specific trailing promos:
  -- "本小章还未完，请点击下一页继续阅读后面精彩内容！"
  text = regex_replace(text, "(?im)本小章还未完.*?继续阅读.*?$", "")
  -- "《{novel}》无错的章节将持续在书海阁小说网小说网更新..."
  text = regex_replace(text, "(?im)《[^》]*》无错的章节将持续.*?$", "")
  -- "喜欢{novel}请大家收藏：(m.shuhaige.net)..."
  text = regex_replace(text, "(?im)喜欢.*?请大家收藏[:：].*$", "")
  -- "站内无任何广告,还请大家收藏和推荐书海阁小说网！"
  text = regex_replace(text, "(?im)站内无任何广告.*?$", "")

  -- Collapse a duplicated chapter-title prefix at the start.
  text = regex_replace(text,
    "(?i)\\A[\\s\\p{Z}\\uFEFF]*" ..
    "((?:第[\\d〇零一二三四五六七八九十百千两\\d]+[章节卷回部集篇]|Chapter\\s+\\d+)" ..
    "(?:\\s*[:：.\\-—]\\s*|\\s+))" ..
    "\\1" ..
    "(?:[\\s\\p{Z}\\uFEFF]*[\\n\\r]+|[\\s\\p{Z}\\uFEFF]+)",
    "")

  -- Strip a single leading chapter title.
  text = regex_replace(text,
    "(?i)\\A[\\s\\p{Z}\\uFEFF]*" ..
    "(?:(?:第[\\d一二三四五六七八九十百]+[章节]|Chapter\\s+\\d+)" ..
    "[^\\n\\r]*[\\n\\r\\s]*)+", "")

  -- Strip translator / editor attribution lines.
  text = regex_replace(text,
    "(?im)^\\s*(翻译|譯者|译者|編輯|编辑|校對|校对|更新|閱讀|阅读|最新閱讀|最新阅读)" ..
    "[:\\s：][^\\n\\r]{0,70}(\\r?\\n|$)", "")

  text = string_trim(text)
  return text
end

-- ── Catalog ─────────────────────────────────────────────────────────────────
-- /shuku/0_0_0_{page}.html — category_status_sort_page (all default)

function getCatalogList(index)
  local page = index + 1
  local url = baseUrl .. "shuku/0_0_0_" .. tostring(page) .. ".html"
  local r = http_get(url)
  if not r.success then return { items = {}, hasNext = false } end

  local items = {}
  for _, li in ipairs(html_select(r.body, "ul.list li")) do
    local titleEl = html_select_first(li.html, "p.bookname a")
    if titleEl then
      local bookUrl = absUrl(titleEl.href)
      local t = string_clean(titleEl.text)
      if bookUrl ~= "" and t ~= "" then
        -- Cover: shuhaige doesn't show covers in the list
        table.insert(items, {
          title = t,
          url   = bookUrl,
          cover = ""
        })
      end
    end
  end

  -- hasNext: look for "下一页" link.
  local hasNext = false
  for _, a in ipairs(html_select(r.body, "a[href*='shuku']")) do
    local txt = string_clean(a.text)
    if txt == "下一页" or txt == "下页" or txt == "»" then
      hasNext = true
      break
    end
  end
  if #items >= 10 then hasNext = true end

  return { items = items, hasNext = hasNext }
end

-- ── Search (POST form) ──────────────────────────────────────────────────────
-- POST /search.html with body searchkey={query}

function getCatalogSearch(index, query)
  if index > 0 then return { items = {}, hasNext = false } end

  local payload = "searchkey=" .. url_encode(query)
  local r = http_post(baseUrl .. "search.html", payload, {
    headers = { ["Content-Type"] = "application/x-www-form-urlencoded" }
  })
  if not r.success then return { items = {}, hasNext = false } end

  local items = {}
  for _, li in ipairs(html_select(r.body, "ul.list li")) do
    local titleEl = html_select_first(li.html, "p.bookname a")
    if titleEl then
      local bookUrl = absUrl(titleEl.href)
      local t = string_clean(titleEl.text)
      if bookUrl ~= "" and t ~= "" then
        table.insert(items, {
          title = t,
          url   = bookUrl,
          cover = ""
        })
      end
    end
  end

  return { items = items, hasNext = false }
end

-- ── Book details ────────────────────────────────────────────────────────────

function getBookTitle(bookUrl)
  local r = http_get(bookUrl)
  if not r.success then return nil end
  local el = html_select_first(r.body, "h1")
  if el then return string_clean(el.text) end
  return nil
end

function getBookCoverImageUrl(bookUrl)
  local r = http_get(bookUrl)
  if not r.success then return nil end
  local src = html_attr(r.body, ".bookimg img, .cover img, #fmimg img, img", "src")
  if src ~= "" then return absUrl(src) end
  return nil
end

function getBookDescription(bookUrl)
  local r = http_get(bookUrl)
  if not r.success then return nil end
  local el = html_select_first(r.body, ".intro, .description, #intro")
  if el then return string_trim(el.text) end
  return nil
end

-- ── Chapter list ────────────────────────────────────────────────────────────
-- shuhaige book page lists chapters in <ul class="vlist"><li><a> format.
-- Chapters are listed newest-first; we reverse to oldest-first.
-- The book page only shows the latest ~10 chapters inline. To get the full
-- list, click "查看全部章节" (view all chapters) which loads an AJAX endpoint.
-- For simplicity, we return the inline chapters (typically 10-20 latest).

function getChapterList(bookUrl)
  local r = http_get(bookUrl)
  if not r.success then return {} end

  local raw = {}
  for _, a in ipairs(html_select(r.body, "ul.vlist li a[href]")) do
    local chUrl = absUrl(a.href)
    local t = string_clean(a.text)
    if chUrl ~= "" and t ~= "" then
      table.insert(raw, { title = t, url = chUrl })
    end
  end

  -- Reverse: site lists newest first; engine expects oldest first.
  local chapters = {}
  for i = #raw, 1, -1 do
    table.insert(chapters, raw[i])
  end

  return chapters
end

-- ── Hash for updates ───────────────────────────────────────────────────────

function getChapterListHash(bookUrl)
  local r = http_get(bookUrl)
  if not r.success then return nil end
  -- Use the first chapter link in ul.vlist (newest chapter).
  local el = html_select_first(r.body, "ul.vlist li a[href]")
  if el then return el.href end
  return nil
end

-- ── Chapter text (multi-page) ──────────────────────────────────────────────
-- Same multi-page pattern as xbiquge: {chapterId}_{N}.html for pages 2+.
-- Content in <div class="content"> with <p> paragraphs.

local function extractPageText(pageHtml)
  local cleaned = html_remove(pageHtml,
    "script", "style",
    "ins", "iframe",
    ".adsbygoogle",
    ".bottem",        -- prev/next nav
    ".bottem2",
    ".page"
  )
  local el = html_select_first(cleaned, ".content")
  if not el then
    el = html_select_first(cleaned, "#content")
    if not el then
      el = html_select_first(cleaned, "#chaptercontent")
      if not el then return "" end
    end
  end
  return html_text(el.html)
end

function getChapterText(html, url)
  -- Extract chapterFile and startPage for multi-page detection.
  -- url = ".../1397/152060484.html"       → chapterFile="152060484", currentPage=1
  -- url = ".../1397/152060484_2.html"      → chapterFile="152060484", currentPage=2
  local chapterFile, startPage = string.match(url, "/([^/]+)_(%d+)%.html$")
  if not chapterFile then
    chapterFile = string.match(url, "/([^/]+)%.html$") or ""
    startPage = "1"
  end
  local currentPage = tonumber(startPage) or 1
  local chapterPattern = string.gsub(chapterFile, "%%", "%%%%")
  chapterPattern = "^" .. chapterPattern .. "_(%d+)%.html$"

  local parts = {}
  local first = extractPageText(html)
  if first ~= "" then table.insert(parts, first) end

  -- Walk FORWARD only: look for {chapterFile}_{currentPage+1}.html.
  local currentHtml = html
  for _ = 1, 30 do
    local nextPageUrl = nil
    local nextPageNum = nil
    for _, a in ipairs(html_select(currentHtml, "a[href]")) do
      local href = a.href or ""
      local fname = string.match(href, "/([^/]+)$") or ""
      local pageNum = string.match(fname, chapterPattern)
      if pageNum then
        local n = tonumber(pageNum)
        if n and n == currentPage + 1 then
          nextPageUrl = absUrl(href)
          nextPageNum = n
          break
        end
      end
    end

    if not nextPageUrl then break end

    local pr = http_get(nextPageUrl)
    if not pr.success then break end

    local sub = extractPageText(pr.body)
    if sub ~= "" then table.insert(parts, sub) end

    currentPage = nextPageNum
    currentHtml = pr.body
  end

  local combined = table.concat(parts, "\n\n")
  return applyStandardContentTransforms(combined)
end
