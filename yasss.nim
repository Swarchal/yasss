import std/[os, strutils, strformat, sequtils, algorithm, json, sugar]

import mustache
import markdown


const
  TemplateDir = @["./templates"]
  PublicDir = "./docs"


type
  FrontMatter = object
    title: string
    formattedTitle: string
    description: string
    date: string
    public: bool

  Post = object
    frontmatter: FrontMatter
    body: string


func formatTitle(name: string): string =
  ## remove any odd characters, replace space with underscore
  var nameFmt = name.multiReplace(
    (" ", "_"),
    (":", ""),
    ("?", ""),
    (".", ""),
    (",", ""),
    ("!", ""),
    ("-", ""),
  )
  return nameFmt


proc parseFrontMatter(text: string): FrontMatter =
  ## parse frontmatter from raw markdown text
  # could use a yaml formatter, but one less dependency
  var
    isFrontMatter = false
    frontMatterLines: seq[string]
    title, formattedTitle, description, date: string
    public: bool = true
  for line in text.split("\n"):
    if line.startswith("---"):
      isFrontMatter = not isFrontMatter
      continue
    if isFrontMatter:
      frontMatterLines.add(line)
  # parse out key-value pairs from frontMatterLines
  for line in frontMatterLines:
    if line.startswith("title"):
      title = line.split(":")[^1].strip()
      formattedTitle = formatTitle(title)
    if line.startswith("description"):
      description = line.split(":")[^1].strip()
    if line.startswith("date"):
      date = line.split(":")[^1].strip()
    if line.startswith("public"):
      public = line.split(":")[^1].strip().toLower().startswith("t")
  return FrontMatter(
    title: title,
    formattedtitle: formattedTitle,
    description: description,
    date: date,
    public: public
  )


proc parseBody(text: string): string =
  ## get body from raw markdown text that includes frontmatter
  var
    body: seq[string]
    isFrontMatter = false
  for line in text.split("\n"):
    if line.startswith("---"):
      isFrontMatter = not isFrontMatter
      continue
    if not isFrontMatter:
      body.add(line)
  return markdown(body.join("\n"))


proc parsePost(text: string): Post =
  ## return Post object from raw markdown text
  let
    frontmatter = text.parseFrontMatter()
    body = text.parseBody()
  return Post(frontmatter: frontmatter, body: body)


proc getAllPosts(fpath: string = "./posts"): seq[Post] =
  ## read in all posts as markdown text
  return walkFiles(fmt"{fpath}/*.md").toSeq().map(readFile).map(parsePost)


func cmpDate(x, y: FrontMatter): int =
  ## custom cmp operator to sort by FrontMatter.date
  cmp(x.date, y.date)


proc createIndex(posts: seq[Post]) =
  ## create context for index template
  var frontMatters: seq[FrontMatter]
  for post in posts:
    frontMatters.add(post.frontMatter)
  frontMatters = frontMatters.filter(x => x.public == true)
  frontMatters.sort(cmpDate, Descending)
  let context = newContext(searchDirs=TemplateDir)
  context["posts"] = %frontMatters
  var
    index_html = "{{ >index }}".render(context)
    save_path = fmt"{PublicDir}/index.html"
  writeFile(save_path, index_html)


proc createPosts(posts: seq[Post]) =
  for post in posts.filter(x => x.frontMatter.public == true):
    echo fmt" - generating post: {post.frontMatter.title}"
    let context = newContext(searchDirs=TemplateDir)
    context["title"] = post.frontMatter.title
    context["body"] = post.body
    var
      post_html = "{{ >post }}".render(context)
      save_path = fmt"{PublicDir}/{post.frontMatter.formattedTitle}.html"
    writeFile(save_path, post_html)


proc main() =
  # TODO: command line arguments
  let posts = getAllPosts()
  posts.createIndex()
  posts.createPosts()


when isMainModule:
  main()
