// name: Sketchy
// description: A quick, grainy pencil sketch, made the way photo editors make
// description: one: the picture's blurred negative dodged over it, so flat
// description: areas burn out to white paper and only the edges stay, as soft
// description: grey pencil lines.
// tags: art, drawing, pencil, sketch, black and white

const float PI2 = 6.2831853072;

// How far the blur reaches, in pixels.
const float Reach = 9.0;

// Colour dodge, as in a photo editor: the bottom layer brightened by the top
// one, the brighter the top the more, until white burns everything white.
vec3 colorDodge(vec3 src, vec3 dst)
{
    return step(0.0, dst) * mix(min(vec3(1.0), dst / max(1.0 - src, 0.0001)), vec3(1.0), step(1.0, src));
}

float greyScale(vec3 col)
{
    return dot(col, vec3(0.3, 0.59, 0.11));
}

// Two random numbers for a point, different at every point but the same at
// it every frame, so the grain stays put like the grain of paper.
vec2 random(vec2 p)
{
    p = fract(p * vec2(314.159, 314.265));
    p += dot(p, p.yx + 17.17);
    return fract((p.xx + p.yx) * p.xy);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 q = fragCoord / iResolution.xy;
    vec3 col = texture2D(iChannel0, q).rgb;

    // The blur is a single sample, a random way off within its reach, spread
    // evenly over the disc around the point. That randomness is what gives
    // the lines their grain.
    vec2 r = random(q);
    r.x *= PI2;
    vec2 cr = vec2(sin(r.x), cos(r.x)) * sqrt(r.y);
    vec3 blurred = texture2D(iChannel0, q + cr * (vec2(Reach) / iResolution.xy)).rgb;

    // The blurred negative dodged over the picture: where the two agree, as
    // they do across any flat area, it burns out white, leaving the edges.
    vec3 lighten = colorDodge(col, vec3(1.0) - blurred);
    float res = greyScale(lighten);

    // More contrast, so the lines come out darker against the paper.
    res = pow(res, 3.0);

    fragColor = vec4(vec3(res), 1.0);
}
