// name: VHS Tape
// description: A worn videotape losing its tracking: every line wobbling
// description: sideways, and every so often a big wave of tearing rolling
// description: through, filled with interference, the colours smearing apart.
// tags: retro, tv, tape, 80s, noise

// Simplex noise in two dimensions, by Ian McEwan of Ashima Arts, MIT licence:
// smooth random hills and valleys between -1 and 1, without the grid shaped
// look of plainer noise.

vec3 mod289(vec3 x)
{
    return x - floor(x * (1.0 / 289.0)) * 289.0;
}

vec2 mod289(vec2 x)
{
    return x - floor(x * (1.0 / 289.0)) * 289.0;
}

vec3 permute(vec3 x)
{
    return mod289(((x * 34.0) + 1.0) * x);
}

float snoise(vec2 v)
{
    const vec4 C = vec4(0.211324865405187,    // (3 - sqrt(3)) / 6
                        0.366025403784439,    // (sqrt(3) - 1) / 2
                        -0.577350269189626,   // -1 + 2 * C.x
                        0.024390243902439);   // 1 / 41

    // The corners of the triangle of the simplex grid the point is in.
    vec2 i = floor(v + dot(v, C.yy));
    vec2 x0 = v - i + dot(i, C.xx);
    vec2 i1 = (x0.x > x0.y) ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
    vec4 x12 = x0.xyxy + C.xxzz;
    x12.xy -= i1;

    // A random gradient for each corner.
    i = mod289(i);
    vec3 p = permute(permute(i.y + vec3(0.0, i1.y, 1.0)) + i.x + vec3(0.0, i1.x, 1.0));

    vec3 m = max(0.5 - vec3(dot(x0, x0), dot(x12.xy, x12.xy), dot(x12.zw, x12.zw)), 0.0);
    m = m * m;
    m = m * m;

    // Gradients: 41 points along a line, mapped onto a diamond.
    vec3 x = 2.0 * fract(p * C.www) - 1.0;
    vec3 h = abs(x) - 0.5;
    vec3 ox = floor(x + 0.5);
    vec3 a0 = x - ox;
    m *= 1.79284291400159 - 0.85373472095314 * (a0 * a0 + h * h);

    vec3 g;
    g.x = a0.x * x0.x + h.x * x0.y;
    g.yz = a0.yz * x12.xz + h.yz * x12.yw;
    return 130.0 * dot(m, g);
}

// A hash from arithmetic alone, where the original used the sine one, which
// breaks up into blocks as its input grows with time.
float hash2(vec2 p)
{
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord / iResolution.xy;
    // Wrapped every ten minutes, so the numbers stay small enough to be exact.
    float time = mod(iTime, 600.0) * 2.0;

    // Big, occasional waves of tearing: only the tops of slow noise hills.
    float noise = max(0.0, snoise(vec2(time, uv.y * 0.3)) - 0.3) * (1.0 / 0.7);

    // With a small, constant wobble on top.
    noise += (snoise(vec2(time * 10.0, uv.y * 2.4)) - 0.5) * 0.15;

    // Every line pushed sideways by the noise.
    float xpos = uv.x - noise * noise * 0.25;
    vec3 color = texture2D(iChannel0, vec2(xpos, uv.y)).rgb;

    // Interference mixed into the lines, the stronger the tearing the more.
    float interference = hash2(vec2(floor(fragCoord.y), floor(time * 30.0)));
    color = mix(color, vec3(interference), noise * 0.3);

    // Darker bands four pixels tall, every other four, in the tearing.
    if (floor(mod(fragCoord.y * 0.25, 2.0)) == 0.0)
        color *= 1.0 - 0.15 * noise;

    // The colours smeared apart: green and blue taken from either side, and
    // mostly replaced by the red, so what is left of them fringes the edges.
    color.g = mix(color.r, texture2D(iChannel0, vec2(xpos + noise * 0.05, uv.y)).g, 0.25);
    color.b = mix(color.r, texture2D(iChannel0, vec2(xpos - noise * 0.05, uv.y)).b, 0.25);

    fragColor = vec4(color, 1.0);
}
