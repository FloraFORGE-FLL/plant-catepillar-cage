// ===============================================================
// Parametric Caterpillar & Seedling Protection Cage
// Grid-style dome with push-in stakes that slot into side posts
// Optimized for PHA Filament Printing
// ===============================================================

$fn = 96; // Smoothness factor

// What to render: "assembly" (preview), "cage", "stake" (one, flat),
// "stakes" (all stakes laid flat, centered so they nest inside the cage on one plate),
// or "section" (assembly cut through a stake joint to check the peg-in-socket fit)
part = "assembly"; // ["assembly", "cage", "stake", "stakes", "section"]

// --- PARAMETERS (in mm) ---
dome_diameter = 150;     // Overall outer diameter of the cage wall
dome_height   = 120;     // Total height above ground
side_height   = 40;      // Straight vertical wall before the dome starts curving
wall_thick    = 3;       // Rib depth (radial)
rib_width     = 3.5;     // Rib width across the face
cell_size     = 20;      // Grid pitch (center to center) for ribs and rings
base_band     = 8;       // Solid band around the bottom edge
hub_r         = 12;      // Solid crown where the vertical ribs meet

stake_count   = 4;       // Number of anchor stakes
stake_length  = 30;      // Ground stake depth (below the post)
post_height   = 24;      // How far each stake post runs up the outside wall
post_width    = 12;      // Stake post width (tangential)
post_out      = 6;       // How far the post stands proud of the wall

stake_thick   = 5;       // Stake thickness (radial when installed, Z when printing)
tenon_width   = 8;       // Width of the peg that pushes into the post
tenon_length  = 15;      // Peg length
fit_clear     = 0.3;     // Gap per side between peg and socket; raise if too tight
socket_lead   = 0.8;     // 45-degree flare at the socket mouth; guides the peg in and eats elephant foot
ef_comp       = 0.4;     // Stake's first layer is inset this much so elephant foot doesn't fatten the peg

// --- DERIVED ---
R      = dome_diameter / 2;
cap_h  = dome_height - side_height;
// Ramanujan's approximation for a quarter of the dome's elliptical profile
cap_arc = PI * (3 * (R + cap_h) - sqrt((3 * R + cap_h) * (R + 3 * cap_h))) / 4;

rib_count   = max(8, round(2 * PI * R / cell_size));
side_rows   = max(1, round((side_height - base_band) / cell_size));
cap_rows    = max(2, round(cap_arc / cell_size));

// Solid cage silhouette: straight wall topped by a half-ellipsoid dome
module body(r, cap) {
    translate([0, 0, -1]) cylinder(r = r, h = side_height + 1);
    translate([0, 0, side_height]) scale([1, 1, cap / r]) sphere(r = r);
}

// Thin outer skin the grid is carved from
module shell() {
    difference() {
        body(R, cap_h);
        body(R - wall_thick, cap_h - wall_thick);
        // Ground Level Plane
        translate([0, 0, -dome_height]) cube([dome_diameter * 3, dome_diameter * 3, dome_height * 2], center = true);
    }
}

// Everything that should stay solid: ribs, rings, base band and crown
module grid_mask() {
    big = dome_diameter + 20;

    // Vertical ribs
    for (i = [0 : rib_count - 1])
        rotate([0, 0, i * 360 / rib_count])
            translate([0, -rib_width / 2, -1])
                cube([big, rib_width, dome_height + 10]);

    // Horizontal rings on the straight wall
    for (k = [1 : side_rows]) {
        z = base_band + k * (side_height - base_band) / side_rows;
        translate([0, 0, z - rib_width / 2]) cylinder(r = big, h = rib_width);
    }

    // Horizontal rings on the dome, spaced evenly along its curve. Each is a wedge
    // fanning out from the dome's center so it crosses the surface square-on and
    // keeps rib_width, instead of smearing into a wide band near the crown.
    // The wedge starts at half the radius: one touching the axis breaks older CGAL exports.
    for (k = [1 : cap_rows - 1]) {
        t = k * 90 / cap_rows;
        d = (rib_width / 2) / sqrt(pow(R * sin(t), 2) + pow(cap_h * cos(t), 2)) * 180 / PI;
        r0 = R / 2;
        translate([0, 0, side_height])
            scale([1, 1, cap_h / R])
                rotate_extrude()
                    polygon([[r0 * cos(t - d), r0 * sin(t - d)], [big * cos(t - d), big * sin(t - d)],
                             [big * cos(t + d), big * sin(t + d)], [r0 * cos(t + d), r0 * sin(t + d)]]);
    }

    // Base band and crown hub
    translate([0, 0, -1]) cylinder(r = big, h = base_band + 1);
    cylinder(r = hub_r, h = dome_height + 10);
}

post_depth = wall_thick + post_out;
post_x0    = R - wall_thick;                 // Inner face, flush with the inside of the wall
socket_x   = post_x0 + post_depth / 2;       // Socket runs up the middle of the post

// Post that hugs the outside of the wall, with a 45-degree shoulder blending into it
module post() {
    hull() {
        translate([post_x0, -post_width / 2, 0]) cube([post_depth, post_width, post_height]);
        translate([post_x0, -post_width / 2, 0]) cube([wall_thick, post_width, post_height + post_out]);
    }
}

sock_x = stake_thick + 2 * fit_clear;       // Socket size, radial
sock_y = tenon_width + 2 * fit_clear;       // Socket size, tangential
sock_h = tenon_length + 1;                  // 1 mm headroom above the peg tip

// Blind hole open at the bottom of each post for the stake's peg, flared at the mouth
module socket() {
    translate([socket_x, 0, 0]) {
        translate([-sock_x / 2, -sock_y / 2, -1]) cube([sock_x, sock_y, sock_h + 1]);
        hull() {
            translate([0, 0, -1])
                cube([sock_x + 2 * (socket_lead + 1), sock_y + 2 * (socket_lead + 1), 0.01], center = true);
            translate([0, 0, socket_lead]) cube([sock_x, sock_y, 0.01], center = true);
        }
    }
}

module cage() {
    difference() {
        union() {
            intersection() {
                shell();
                grid_mask();
            }
            // Posts sit on vertical ribs so they read as part of the frame
            for (i = [0 : stake_count - 1])
                rotate([0, 0, i * 360 / stake_count]) post();
        }
        for (i = [0 : stake_count - 1])
            rotate([0, 0, i * 360 / stake_count]) socket();
    }
}

// Stake outline: peg on top, shoulder at ground level that butts against the post,
// blade tapering to a point below. X = across the stake, Y = up.
module stake_profile() {
    c  = 1; // Lead-in chamfer on the peg tip
    tw = tenon_width / 2;
    pw = post_width / 2;
    polygon([
        [-pw, 0], [-tw, 0], [-tw, tenon_length - c], [-tw + c, tenon_length],
        [tw - c, tenon_length], [tw, tenon_length - c], [tw, 0], [pw, 0],
        [0.6, -stake_length], [-0.6, -stake_length]
    ]);
}

// One stake lying flat, as printed, with an inset first layer against elephant foot
module stake() {
    linear_extrude(height = ef_comp) offset(delta = -ef_comp) stake_profile();
    translate([0, 0, ef_comp]) linear_extrude(height = stake_thick - ef_comp) stake_profile();
}

// All stakes side by side, centered so they fit inside the cage's footprint
module stakes_plate() {
    gap = 4;
    pitch = post_width + gap;
    for (i = [0 : stake_count - 1])
        translate([(i - (stake_count - 1) / 2) * pitch, (stake_length - tenon_length) / 2, 0])
            stake();
}

// Stakes pushed into the posts, for previewing the fit
module installed_stakes() {
    for (i = [0 : stake_count - 1])
        rotate([0, 0, i * 360 / stake_count])
            translate([socket_x, 0, 0])
                rotate([0, 0, 90]) rotate([90, 0, 0])
                    linear_extrude(height = stake_thick, center = true) stake_profile();
}

// Assembly sliced through the first stake's joint, looking along the wall
module section() {
    intersection() {
        union() {
            cage();
            color("peru") installed_stakes();
        }
        translate([R - 30, 0, -stake_length - 5]) cube([40, dome_diameter, dome_height + stake_length + 10]);
    }
}

// Render
if (part == "cage") cage();
else if (part == "stake") stake();
else if (part == "stakes") stakes_plate();
else if (part == "section") section();
else {
    cage();
    color("peru") installed_stakes();
}
