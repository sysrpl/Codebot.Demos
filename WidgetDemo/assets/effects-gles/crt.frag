// name: CRT Television
// description: An old tube television: the picture bowed out on a curved
// description: screen with rounded corners, scan lines, the red, green and
// description: blue stripes of the phosphors, and a soft glow around bright
// description: parts.
// tags: retro, tv, screen, scan lines

// How far the screen bows out, across and down.
const vec2 Curve = vec2(0.05, 0.07);

// Scan lines down the picture: 360 is three pixels each at 1080p.
const float Lines = 360.0;

// How round the corners are, as a part of the screen's height.
const float Corner = 0.045;

vec3 picture(vec2 uv)
{
    return texture2D(iChannel0, uv).rgb;
}

// Where on the flat picture this point of the curved screen shows. The
// edges reach beyond the picture, which leaves them dark, bowed borders.
vec2 curved(vec2 uv)
{
    vec2 c = uv * 2.0 - 1.0;
    c *= 1.0 + c.yx * c.yx * Curve;
    return c * 0.5 + 0.5;
}

// 1 on the screen, 0 off it, with the corners rounded and the edge soft.
float screen(vec2 q)
{
    vec2 edge = min(q, 1.0 - q) * vec2(iResolution.x / iResolution.y, 1.0);
    vec2 d = max(vec2(Corner) - edge, 0.0);
    return 1.0 - smoothstep(Corner - 0.003, Corner, length(d));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 pixel = 1.0 / iResolution.xy;
    vec2 uv = fragCoord * pixel;
    vec2 q = curved(uv);
    float glass = screen(q);
    if (glass <= 0.0)
    {
        fragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }

    // The three electron beams never quite line up: red a touch to the
    // right, blue a touch to the left.
    vec3 color = vec3(picture(q + vec2(pixel.x * 0.7, 0.0)).r,
                      picture(q).g,
                      picture(q - vec2(pixel.x * 0.7, 0.0)).b);

    // Glow: light spilling a few pixels around bright parts.
    vec3 around = vec3(0.0);
    for (int i = 0; i < 8; i++)
    {
        float angle = float(i) * 0.7853982;
        around += picture(q + vec2(cos(angle), sin(angle)) * pixel * 4.0);
    }
    around /= 8.0;
    color += around * around * 0.25;

    // Scan lines: each a bright band with a dark gap under it. Brighter
    // lines spread wider, as a stronger beam does, filling the gaps.
    float brightness = dot(color, vec3(0.2126, 0.7152, 0.0722));
    float across = fract(q.y * Lines) - 0.5;
    float width = mix(0.22, 0.42, clamp(brightness, 0.0, 1.0));
    color *= mix(0.5, 1.2, exp(-across * across / (width * width)));

    // The phosphors: every three pixels across, a red, a green and a blue
    // stripe, each letting its own colour through most.
    float stripe = mod(floor(fragCoord.x), 3.0);
    vec3 mask = stripe < 1.0 ? vec3(1.0, 0.72, 0.72)
              : stripe < 2.0 ? vec3(0.72, 1.0, 0.72)
              : vec3(0.72, 0.72, 1.0);
    color *= mask * 1.2;

    // A little darker towards the edges of the tube.
    vec2 c = q * 2.0 - 1.0;
    color *= 1.0 - 0.2 * dot(c, c);

    fragColor = vec4(clamp(color, 0.0, 1.0) * glass, 1.0);
}
