// Which build this is (#500), for the foot of the title menu: the Deck build's build_id.txt (src/deck/build.sh
// writes it: no .git there), else git's short hash (+changes for local edits), and the network version, which
// decides whether two devices play together (creel/src/net/lan.lobster).

def build_label(id_file:string, git_head:string, git_dirty:string, net:string) -> string:
    let file = tokenize(id_file, "\n", " \t")
    var commit = if file.length and file[0] != "": file[0] else: ""
    if commit == "":
        let head = tokenize(git_head, "\n", " \t")
        if head.length and head[0] != "":
            commit = head[0]
            if tokenize(git_dirty, "\n", " \t").length: commit += "+changes"
    return "build {if commit != "": commit else: "unknown"}, net {net}"

var build_label_cache = ""

// This build's line (asked once: git runs at most twice).
def build_label_now(net:string) -> string:
    if build_label_cache != "": return build_label_cache
    let id_file = read_file("build_id.txt") or ""
    var head = ""
    var dirty = ""
    if id_file == "":
        let code, out = launch_subprocess([ "git", "rev-parse", "--short", "HEAD" ])
        if code == 0:
            head = out
            let c2, out2 = launch_subprocess([ "git", "status", "--porcelain", "--untracked-files=no" ])
            if c2 == 0: dirty = out2
    build_label_cache = build_label(id_file, head, dirty, net)
    return build_label_cache
