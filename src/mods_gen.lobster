// Writes model/mods_active.lobster for these mods: each mod's Lobster model files (mod.json "models")
// copied into model/mods/ and imported, and build_mods(base, colours) asking each mod's build_mod_<id> in turn.
// (Lobster resolves imports when it compiles, so a mod's code joins the game before it starts.)
//   lobster mods_gen.lobster -- [mod id ...]

import std
import dictionary
import .gen.json

let ids = command_line_arguments()
var imports = ""
let chain = []::string
for(ids) id:
    let manifest = read_file("../mods/{id}/mod.json")
    if not manifest:
        print "mods_gen: no mod {id}"
        continue
    for(gstrs(parse_json(manifest), "models")) rel:
        let text = read_file("../mods/{id}/{rel}")
        assert text
        let leaf = tokenize(rel, "/", "")
        let name = "{id}_" + leaf[leaf.length - 1].substring(0, leaf[leaf.length - 1].length - 8)
        assert write_file("model/mods/{name}.lobster", text)
        imports += "import .mods.{name}\n"
    chain.push("build_mod_{id}(base, c)")
let body = if chain.length: concat_string(chain, " or ") else: "nil"
let out = "// The active mods\' Lobster models (written by mods_gen.lobster from each mod.json\'s \"models\"; play.sh\n" +
          "// runs it with the mods asked for). " + (if ids.length: "Mods: " + concat_string(ids, ", ") + "." else: "This is the file with none.") + "\n\n" +
          imports + (if imports != "": "\n" else: "") +
          "def build_mods(base:string, c:Colours) -> Spec?: return " + body + "\n"
assert write_file("model/mods_active.lobster", out)
