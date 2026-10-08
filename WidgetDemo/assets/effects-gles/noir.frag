// name: Film Noir
// description: A 1940s crime picture: hard black and white with deep, crushed
// description: shadows and bright silvery highlights, heavy grain, and the
// description: edges of the frame sunk in darkness.
// tags: film, black and white, movie, dark, vintage

const float FilmRate = 24.0;

// How dark the corners go, 0 not at all to 1 black.
const float Vignette = 0.7;

// How much brighter the picture is made, 0.2 for a fifth. The vignette is
// left as dark as it was: the brightening fades out towards the corners.
const float Brighten = 0.2;

float hash2(vec2 p)
{
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord / iResolution.xy;
    float frame = mod(floor(iTime * FilmRate), 4096.0);

    float level = dot(texture2D(iChannel0, uv).rgb, vec3(0.2126, 0.7152, 0.0722));

    // Hard contrast: everything below a fifth goes to black, everything above
    // four fifths to white, and a steep S curve between them.
    level = smoothstep(0.1, 0.85, level);
    level = pow(level, 1.25);

    // Coarse grain, stronger in the mid tones as film grain is.
    float grain = hash2(fragCoord + vec2(frame * 13.0, frame * 7.0)) - 0.5;
    level += grain * 0.12 * (1.0 - abs(level - 0.5) * 1.6);

    // The corners sunk in shadow, as a lamp lighting the middle of a scene,
    // and everything else brightened.
    vec2 d = (uv - 0.5) * vec2(iResolution.x / iResolution.y, 1.0);
    float edge = smoothstep(0.25, 0.95, length(d));
    level *= (1.0 - edge * Vignette) * (1.0 + Brighten * (1.0 - edge));

    // A faint cool silver, rather than a flat grey.
    fragColor = vec4(clamp(vec3(level) * vec3(0.97, 1.0, 1.04), 0.0, 1.0), 1.0);
}
