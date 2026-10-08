// name: Rain on Glass
// description: Watching through a rainy window: the glass misted over,
// description: beaded with raindrops that each show the scene sharp and
// description: upside down, and drops running down leaving clear trails.
// tags: weather, water, glass, window, blur

// The grid the beads sit on, in pixels: one bead at most to a square.
const float BeadSpacing = 30.0;

// The lanes the running drops fall down, in pixels across.
const float LaneWidth = 80.0;

// How much the mist blurs the scene, in pixels, and how pale it makes it.
const float MistBlur = 4.0;
const float MistPale = 0.15;

float hash(float n)
{
    n = fract(n * 0.1031);
    n *= n + 33.33;
    n *= n + n;
    return fract(n);
}

float hash2(vec2 p)
{
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

// A drop at this offset from its middle, of this size: how much of it there
// is here, and where it bends the view to. A drop is a lens, so it shows the
// scene behind turned over and shrunk into it: points near its rim look out
// on the far side of its middle. The result is the offset to look at, in
// pixels, and how much of the drop is here, 0 to 1.
vec3 drop(vec2 fromMiddle, vec2 size)
{
    vec2 d = fromMiddle / size;
    float r = length(d);
    float cover = 1.0 - smoothstep(0.85, 1.0, r);
    return vec3(-fromMiddle * 1.8, cover);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 pixel = 1.0 / iResolution.xy;
    vec2 uv = fragCoord * pixel;
    float t = mod(iTime, 3600.0);

    vec3 lens = vec3(0.0);
    float clear = 0.0;

    // Beads: at most one to a square of the grid, placed and sized at random,
    // each forming slowly, sitting a while, then gone, to form again elsewhere.
    vec2 square = floor(fragCoord / BeadSpacing);
    float life = 6.0 + 6.0 * hash2(square + 3.3);
    float age = t / life + hash2(square);
    float turn = floor(age);
    float seed = hash2(square + turn * 7.1);
    if (seed > 0.35)
    {
        vec2 middle = (square + 0.5 + (vec2(hash2(square + turn), hash2(square + turn + 9.7)) - 0.5) * 0.6) * BeadSpacing;
        float grown = smoothstep(0.0, 0.2, fract(age)) * (1.0 - smoothstep(0.85, 1.0, fract(age)));
        float radius = mix(2.5, 6.0, hash2(square + turn * 3.9)) * grown;
        if (radius > 0.5)
        {
            vec3 bead = drop(fragCoord - middle, vec2(radius));
            if (bead.z > lens.z)
                lens = bead;
        }
    }

    // Running drops: one to a lane, each falling at its own speed, wobbling
    // as it goes, and leaving a trail wiped clear of mist behind it, with a
    // few small beads left in the trail.
    float lane = floor(fragCoord.x / LaneWidth);
    float speed = mix(60.0, 170.0, hash(lane * 1.7));
    float fall = iResolution.y + 300.0;
    float dropY = iResolution.y + 100.0 - mod(t * speed + hash(lane * 3.1) * fall, fall);
    float wobble = sin(dropY * 0.03 + lane * 2.1) * 6.0;
    float dropX = (lane + 0.5) * LaneWidth + (hash(lane * 5.3) - 0.5) * LaneWidth * 0.4 + wobble;
    if (hash(lane * 9.1) > 0.3)
    {
        vec3 running = drop(fragCoord - vec2(dropX, dropY), vec2(7.0, 9.0));
        if (running.z > lens.z)
            lens = running;

        // The trail, above the drop, fading as it goes up, narrow and
        // following the drop's wobble as it was when it passed.
        float above = fragCoord.y - dropY;
        if (above > 0.0 && above < 220.0)
        {
            float trailX = (lane + 0.5) * LaneWidth + (hash(lane * 5.3) - 0.5) * LaneWidth * 0.4
                + sin(fragCoord.y * 0.03 + lane * 2.1) * 6.0;
            float fade = 1.0 - above / 220.0;
            clear = max(clear, (1.0 - smoothstep(2.0, 4.0, abs(fragCoord.x - trailX))) * fade * 0.8);

            // Little beads left along the trail every so often.
            float spot = floor(fragCoord.y / 14.0);
            if (hash(spot + lane * 13.0) > 0.5)
            {
                vec2 left = vec2(trailX + (hash(spot * 1.3 + lane) - 0.5) * 4.0, (spot + 0.5) * 14.0);
                vec3 bead = drop(fragCoord - left, vec2(mix(1.5, 3.0, hash(spot + lane * 2.0)) * fade));
                if (bead.z > lens.z)
                    lens = bead;
            }
        }
    }

    // The misted glass: the scene blurred and paled.
    vec3 mist = vec3(0.0);
    for (int y = -1; y <= 1; y++)
        for (int x = -1; x <= 1; x++)
            mist += texture2D(iChannel0, uv + vec2(x, y) * MistBlur * pixel).rgb;
    mist = mix(mist / 9.0, vec3(0.75), MistPale);

    // Through a clear trail, the scene as it is; through a drop, the scene
    // bent by it, with a glint of light near its top.
    vec3 sharp = texture2D(iChannel0, uv).rgb;
    vec3 color = mix(mist, sharp, clear);
    vec3 bent = texture2D(iChannel0, uv + lens.xy * pixel).rgb;
    color = mix(color, bent, lens.z);
    color += vec3(0.25) * lens.z * smoothstep(0.3, 1.0, -lens.y / 12.0) * 0.5;

    fragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
