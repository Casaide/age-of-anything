// Fixed bugs the placement check's fixtures put back, to prove it still catches each one. Only fixtures set these.

class OldBugs:
    legs_unmirrored = false   // far-side and flipped legs baked as modelled (the newt)
    rat_leans_back = false    // the rat's trunk leaning back
    rat_head_stays = false    // its head left off the leaning trunk's neck
    rat_armour_off = false    // worn armour too far along its trunk
    bob_before_foot = false   // the walk's bob, before the body rode on its planted foot
    seat_dropped = false      // riders dropped a fixed amount below the seat

let old_bugs = OldBugs {}
