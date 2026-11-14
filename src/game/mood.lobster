// The match's mood (data/atmosphere.json, view/atmosphere.lobster): a mood by name, or "<a>~<b>@<t>", the light t of
// the way from mood a to mood b (atmo_set_between: 0 all a, 1 all b). Returns what's wrong, or "".
def atmo_set_asked(j:JV, mood:string) -> string:
    let at = tokenize(mood, "@", "")
    let ab = tokenize(at[0], "~", "")
    if at.length == 2 and ab.length == 2: return atmo_set_between(j, ab[0], ab[1], string_to_float(at[1]))
    return atmo_set(j, mood)
