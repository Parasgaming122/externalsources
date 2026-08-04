-- ── Metadata ────────────────────────────────────────────────────────────────
id       = "rayforboe"
name     = "RayForBoe"
version  = "1.0.0"
baseUrl  = "https://www.rayforboe.com/"
language = "zh"
icon     = "https://raw.githubusercontent.com/HnDK0/external-sources/main/icons/rayforboe.png"

-- ── Site notes ──────────────────────────────────────────────────────────────
-- rayforboe (顶级看书网) is a Simplified-Chinese novel/article site.
-- Unlike traditional multi-chapter novel sites, rayforboe uses a blog-like
-- structure where each "novel" is a single article page with content.
--
-- URL patterns:
--   Home:       /                                  (lists featured categories)
--   Category:   /sort/                             (lists all categories)
--   Cat listing:/{category-slug}/                  e.g. /mgbxsa/ (穿越小说)
--   Article:    /{category-slug}/{id}              e.g. /mgbxsa/299672
--                (id can be numeric or a slug like OIP-C.v0_FQ65AHoMVNDotf085frjwhN)
--
-- Content structure:
--   <article class="single-post">
--     <header class="single-title">Chapter Title</header>
--     <div class="entry">
--       <p>...</p><p>...</p>...   (chapter content)
--       <blockquote>...</blockquote>  (sometimes)
--     </div>
--     <nav class="article-nav">上一篇：... (prev article link)</nav>
--     <div class="related-posts">... (related articles)</div>
--   </article>
--
-- Notes:
--   - Each "book" is a single page — no multi-chapter structure.
--   - The "chapter list" returns just the single article.
--   - Content is in article .entry, using <p> paragraphs.
--   - Noise: <blockquote> at the end (keyword stuffing), <script> (count.php).
-- ────────────────────────────────────────────────────────────────────────────

-- ── Helpers ─────────────────────────────────────────────────────────────────

local function absUrl(href)
  if not href or href == "" then return "" end
  if string_starts_with(href, "http") then return href end
  if string_starts_with(href, "//") then return "https:" .. href end
  return url_resolve(baseUrl, href)
end

-- Apply standard content transforms.
local function applyStandardContentTransforms(text)
  if not text or text == "" then return "" end
  text = string_normalize(text)

  -- Strip site domain references.
  local domain = baseUrl:gsub("https?://", ""):gsub("^www%.", ""):gsub("/$", "")
  text = regex_replace(text, "(?i)" .. domain .. ".*?\\n", "")

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
-- The home page lists featured categories and recent articles.
-- We use /sort/ which lists categories, then drill into a category for books.

function getCatalogList(index)
  if index > 0 then return { items = {}, hasNext = false } end

  -- Fetch the home page — it lists recent articles.
  local r = http_get(baseUrl)
  if not r.success then return { items = {}, hasNext = false } end

  local items = {}
  local seen = {}
  -- Articles are linked as /{slug}/{id} — find all such links.
  for _, a in ipairs(html_select(r.body, "a[href]")) do
    local href = a.href or ""
    local t = string_clean(a.text)
    -- Match /{slug}/{id} where slug is alpha and id is numeric or alphanumeric.
    -- Exclude navigation links.
    if t ~= "" and string.find(href, "^/[^/]+/[^/]+$") then
      local slug, id = string.match(href, "^/([^/]+)/([^/]+)$")
      if slug and id and slug ~= "" and id ~= "" and
         not string.find(slug, "%.html$") and
         not string.find(slug, "sitemap") and
         not string.find(slug, "search") and
         not string.find(slug, "sort") and
         not string.find(slug, "login") and
         not string.find(slug, "register") then
        local fullUrl = absUrl(href)
        if not seen[fullUrl] then
          seen[fullUrl] = true
          table.insert(items, {
            title = t,
            url   = fullUrl,
            cover = ""
          })
        end
      end
    end
    if #items >= 30 then break end
  end

  return { items = items, hasNext = false }
end

-- ── Search ──────────────────────────────────────────────────────────────────
-- rayforboe uses /search.php?q={query} or /index.php?q={query}.
-- The search form on the home page uses GET.

function getCatalogSearch(index, query)
  if index > 0 then return { items = {}, hasNext = false } end

  local encoded = url_encode(query)
  -- Try /index.php?q= first (DedeCMS pattern)
  local url = baseUrl .. "index.php?q=" .. encoded
  local r = http_get(url)
  if not r.success then return { items = {}, hasNext = false } end

  local items = {}
  local seen = {}
  for _, a in ipairs(html_select(r.body, "a[href]")) do
    local href = a.href or ""
    local t = string_clean(a.text)
    if t ~= "" and string.find(href, "^/[^/]+/[^/]+$") then
      local slug, id = string.match(href, "^/([^/]+)/([^/]+)$")
      if slug and id and slug ~= "" and id ~= "" and
         not string.find(slug, "%.html$") and
         not string.find(slug, "sitemap") and
         not string.find(slug, "search") and
         not string.find(slug, "sort") then
        local fullUrl = absUrl(href)
        if not seen[fullUrl] then
          seen[fullUrl] = true
          table.insert(items, {
            title = t,
            url   = fullUrl,
            cover = ""
          })
        end
      end
    end
    if #items >= 30 then break end
  end

  return { items = items, hasNext = false }
end

-- ── Book details ────────────────────────────────────────────────────────────
-- Each "book" is a single article. The article page IS the book page.

function getBookTitle(bookUrl)
  local r = http_get(bookUrl)
  if not r.success then return nil end
  -- Title is in article header .single-title or h1
  local el = html_select_first(r.body, "article .single-title h1, article header h1, h1")
  if el then return string_clean(el.text) end
  return nil
end

function getBookCoverImageUrl(bookUrl)
  -- rayforboe articles don't have covers
  return nil
end

function getBookDescription(bookUrl)
  local r = http_get(bookUrl)
  if not r.success then return nil end
  -- Use the first 200 chars of the article content as description.
  local el = html_select_first(r.body, "article .entry")
  if el then
    local text = string_trim(el.text)
    if text ~= "" then
      -- Truncate to ~200 chars
      if #text > 200 then
        text = string.sub(text, 1, 200) .. "..."
      end
      return text
    end
  end
  return nil
end

-- ── Chapter list ────────────────────────────────────────────────────────────
-- rayforboe articles are single-page — the "chapter list" is just the
-- article itself. We return a single "chapter" that points to the article URL.

function getChapterList(bookUrl)
  -- Fetch the book page to get the title.
  local r = http_get(bookUrl)
  if not r.success then return {} end

  local titleEl = html_select_first(r.body, "article .single-title h1, article header h1, h1")
  local title = "正文"
  if titleEl then
    local fullTitle = string_clean(titleEl.text)
    -- Use the full title as the chapter title.
    if fullTitle ~= "" then title = fullTitle end
  end

  return { { title = title, url = bookUrl } }
end

-- ── Hash for updates ───────────────────────────────────────────────────────

function getChapterListHash(bookUrl)
  local r = http_get(bookUrl)
  if not r.success then return nil end
  -- Use the article's last-modified header or the title text length as hash.
  local el = html_select_first(r.body, "article .entry")
  if el then return tostring(#el.text) end
  return nil
end

-- ── Chapter text ────────────────────────────────────────────────────────────
-- Content is in <article> <div class="entry">. Strip <blockquote> (keyword
-- stuffing at the end), <script> (count.php), and <nav> (prev/next article).

function getChapterText(html, url)
  local cleaned = html_remove(html,
    "script", "style",
    "nav",              -- prev/next article nav
    "blockquote",       -- keyword stuffing block at the end
    ".related-posts",   -- related articles
    ".article-action",  -- share/report buttons
    "ins", "iframe",
    ".adsbygoogle"
  )

  local el = html_select_first(cleaned, "article .entry")
  if not el then
    el = html_select_first(cleaned, ".entry")
    if not el then
      el = html_select_first(cleaned, "article")
      if not el then return "" end
    end
  end

  return applyStandardContentTransforms(html_text(el.html))
end
