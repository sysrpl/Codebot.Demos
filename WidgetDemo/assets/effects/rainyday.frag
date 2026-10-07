// name: Rainy Day
// description: Watching through a window on a stormy day: the glass fogged,
// description: drops running down it in wavering streaks that leave clear
// description: trails, beads forming and fading, each drop showing the scene
// description: behind it, the rain coming and going, and now and then lightning.
// tags: weather, rain, glass, window, blur, storm, moody

// "Heartfelt" by Martijn Steinrucken (BigWings), 2017, licensed Creative
// Commons Attribution-NonCommercial-ShareAlike 3.0, and so is this effect.
// Changed from his: the heart and the story built round it are gone, so it
// just rains, and nothing is steered by the mouse.
//
// His blur reads the video from its mipmaps, smaller and smaller halvings of
// it, which the screen makes for video effects; texture2D's third argument
// asks for how many halvings in.

#define S(a, b, t) smoothstep(a, b, t)

// How long before the rain starts over, in seconds. The drops' positions
// come from hashes of numbers that grow with time, and past this they would
// lose precision and the drops their shapes.
const float Wrap = 600.0;

// His blur levels were chosen for a smaller video than 1080p; this many
// halvings more give the same blur on ours.
const float MipShift = 0.6;

// Three random numbers for one, from Dave Hoskins.
vec3 N13(float p)
{
    vec3 p3 = fract(vec3(p) * vec3(0.1031, 0.11369, 0.13787));
    p3 += dot(p3, p3.yzx + 19.19);
    return fract(vec3((p3.x + p3.y) * p3.z, (p3.x + p3.z) * p3.y, (p3.y + p3.z) * p3.x));
}

float N(float t)
{
    return fract(sin(t * 12345.564) * 7658.76);
}

// Rises quickly to 1 by b, then falls slowly back to 0 by 1: the way a drop
// hangs, then slides.
float Saw(float b, float t)
{
    return S(0.0, b, t) * S(1.0, b, t);
}

// Running drops: a grid of columns, each drop wavering side to side as it
// slides, a trail wiped clear behind it and small droplets left in the trail.
// Returns how much drop there is here, and how much clear trail.
vec2 DropLayer2(vec2 uv, float t)
{
    vec2 UV = uv;

    uv.y += t * 0.75;
    vec2 a = vec2(6.0, 1.0);
    vec2 grid = a * 2.0;
    vec2 id = floor(uv * grid);

    float colShift = N(id.x);
    uv.y += colShift;

    id = floor(uv * grid);
    vec3 n = N13(id.x * 35.2 + id.y * 2376.1);
    vec2 st = fract(uv * grid) - vec2(0.5, 0.0);

    float x = n.x - 0.5;

    float y = UV.y * 20.0;
    float wiggle = sin(y + sin(y));
    x += wiggle * (0.5 - abs(x)) * (n.z - 0.5);
    x *= 0.7;
    float ti = fract(t + n.z);
    y = (Saw(0.85, ti) - 0.5) * 0.9 + 0.5;
    vec2 p = vec2(x, y);

    float d = length((st - p) * a.yx);

    float mainDrop = S(0.4, 0.0, d);

    float r = sqrt(S(1.0, y, st.y));
    float cd = abs(st.x - x);
    float trail = S(0.23 * r, 0.15 * r * r, cd);
    float trailFront = S(-0.02, 0.02, st.y - y);
    trail *= trailFront * r * r;

    y = UV.y;
    y = fract(y * 10.0) + (st.y - 0.5);
    float dd = length(st - vec2(x, y));
    float droplets = S(0.3, 0.0, dd);
    float m = mainDrop + droplets * r * trailFront;

    return vec2(m, trail);
}

// Beads: a fine grid of small drops, each forming and fading at its own time.
float StaticDrops(vec2 uv, float t)
{
    uv *= 40.0;

    vec2 id = floor(uv);
    uv = fract(uv) - 0.5;
    vec3 n = N13(id.x * 107.45 + id.y * 3543.654);
    vec2 p = (n.xy - 0.5) * 0.7;
    float d = length(uv - p);

    float fade = Saw(0.025, fract(t + n.z));
    float c = S(0.3, 0.0, d) * fract(n.z * 10.0) * fade;
    return c;
}

// The beads and two layers of running drops, of two sizes, each as heavy as
// its amount asks. Returns how much drop there is here, and how much trail.
vec2 Drops(vec2 uv, float t, float l0, float l1, float l2)
{
    float s = StaticDrops(uv, t) * l0;
    vec2 m1 = DropLayer2(uv, t) * l1;
    vec2 m2 = DropLayer2(uv * 1.85, t) * l2;

    float c = s + m1.x + m2.x;
    c = S(0.3, 1.0, c);

    return vec2(c, max(m1.y * l0, m2.y * l1));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
    vec2 UV = fragCoord / iResolution.xy;
    float T = mod(iTime, Wrap);

    float t = T * 0.2;

    // The rain comes and goes, heavier and lighter over a couple of minutes.
    float rainAmount = sin(T * 0.05) * 0.3 + 0.7;

    // How blurred the scene is behind the fogged glass, and through a drop.
    float maxBlur = mix(3.0, 6.0, rainAmount);
    float minBlur = 2.0;

    // The view drifts slowly in and out.
    float zoom = -cos(T * 0.2);
    uv *= 0.7 + zoom * 0.3;
    UV = (UV - 0.5) * (0.9 + zoom * 0.1) + 0.5;

    float staticDrops = S(-0.5, 1.0, rainAmount) * 2.0;
    float layer1 = S(0.25, 0.75, rainAmount);
    float layer2 = S(0.0, 0.5, rainAmount);

    // The drops, and their slope: each bends the view behind it like a lens.
    vec2 c = Drops(uv, t, staticDrops, layer1, layer2);
    vec2 e = vec2(0.001, 0.0);
    float cx = Drops(uv + e, t, staticDrops, layer1, layer2).x;
    float cy = Drops(uv + e.yx, t, staticDrops, layer1, layer2).x;
    vec2 n = vec2(cx - c.x, cy - c.x);

    // Sharper through drops and down the trails, foggy everywhere else.
    float focus = mix(maxBlur - c.y, minBlur, S(0.1, 0.2, c.x));
    vec3 col = texture2D(iChannel0, UV + n, focus + MipShift).rgb;

    // A slow shift towards cold blue and back.
    t = (T + 3.0) * 0.5;
    float colFade = sin(t * 0.2) * 0.5 + 0.5;
    col *= mix(vec3(1.0), vec3(0.8, 0.9, 1.3), colFade);

    // Lightning: a flicker that now and then builds into a flash.
    float lightning = sin(t * sin(t * 10.0));
    lightning *= pow(max(0.0, sin(t + sin(t))), 10.0);
    col *= 1.0 + lightning;

    // Darker towards the corners.
    vec2 fromMiddle = UV - 0.5;
    col *= 1.0 - dot(fromMiddle, fromMiddle);

    fragColor = vec4(col, 1.0);
}
