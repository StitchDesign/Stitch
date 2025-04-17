//
//  LayerBlockingHepers.swift
//  Stitch
//
//  Created by Christian J Clampitt on 4/17/25.
//

import Foundation


/*
 various inputs are updated, and have the effect of blocking/unblocking part or whole of itself or even other inputs
 
 LAYER GROUP ORIENTATION UPDATED:
 - none: block spacing, block grid layout, block group alignment; for each child, block offset, unblock position
 - horizontal/vertical: unblock spacing, block grid layout, unblock group alignment; for each child, unblock offset, block position
 - grid: unblock spacing, unblock grid layout, block group alignment; for each child, block position and block offset if scroll enabled else unblock offset
 
 
 SIZE UPDATED:
 - for a given dimension, min/max fields get blocked if static else unblocked
 

 SIZING SCENARIO UPDATED:
 - auto: unblock size, block or unblock min/max width and height fields, block aspect ratio
 - constrain height: block height, unblock width, block or unblock min/max width, unblock aspect ratio
 - constrain width: block width, unblock height, block or unblock min/max height, unblock aspect ratio
 

 PIN UPDATED:
 - if pinning: unlock pin, block position, block anchoring
 - else: block pin, unblock position, unblock anchoring

 
 Note: size and scroll mostly operate on other size or scroll inputs.
 
 
 SCROLL X UPDATED:
 - if enabled: unblock scroll x jump inputs, block offset input on children that use a grid
 - else: block scroll x jump inputs, unblock all children's offset input
 
 
 SCROLL Y UPDATED:
 - same as scroll x
 */
