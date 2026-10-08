// name: Night Vision
// description: Through night vision goggles: the scene brightened far beyond
// description: what the eye sees, in grainy phosphor green, lights blooming
// description: into glare, seen through the two round eyepieces.
// tags: sci-fi, green, camera, military, dark

const float FrameRate = 30.0;

const vec3 Phosphor = vec3(0.3, 1.0, 0.35);

float hash2(vec2 p)
{
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float brightness(vec3 color)
{
    return dot(color, vec3(0.2126, 0.7152, 0.0722));
}

// How much of this point the eyepieces show: two round views side by side,
// overlapping in the middle, their edges soft.
float eyepieces(vec2 uv)
{
    vec2 p = (uv - 0.5) * vec2(iResolution.x / iResolution.y, 1.0);
    float radius = 0.47;
    float left = 1.0 - smoothstep(radius - 0.05, radius, length(p - vec2(-0.33, 0.0)));
    float right = 1.0 - smoothstep(radius - 0.05, radius, length(p - vec2(0.33, 0.0)));
    return max(left, right);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 pixel = 1.0 / iResolution.xy;
    vec2 uv = fragCoord * pixel;
    float view = eyepieces(uv);
    if (view <= 0.0)
    {
        fragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }

    // Amplified: dark parts lifted hard, so a dim scene reads clearly.
    float level = pow(brightness(texture2D(iChannel0, uv).rgb), 0.65) * 1.5;

    // Glare: anything bright spills light a long way around it.
    float around = 0.0;
    for (int i = 0; i < 8; i++)
    {
        float angle = float(i) * 0.7853982;
        around += brightness(texture2D(iChannel0, uv + vec2(cos(angle), sin(angle)) * pixel * 9.0).rgb);
    }
    around /= 8.0;
    level += max(around - 0.45, 0.0) * 1.8;

    // Heavy grain, the tube amplifying its own noise along with the light.
    float frame = mod(floor(iTime * FrameRate), 4096.0);
    level += (hash2(fragCoord + vec2(frame * 13.0, frame * 7.0)) - 0.5) * 0.22;

    // Faint lines across, and a little darker towards each eyepiece's rim.
    level *= 0.92 + 0.08 * cos(fragCoord.y * 3.14159);
    vec3 color = Phosphor * level + vec3(0.0, 0.04, 0.0);

    fragColor = vec4(clamp(color, 0.0, 1.0) * view, 1.0);
}
