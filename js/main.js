async function loadShader(url) {
    const res = await fetch(url);
    if (!res.ok) throw new Error(`Failed to load shader: ${url}`);
    return res.text();
}

function compileShader(gl, type, source) {
    const shader = gl.createShader(type);
    gl.shaderSource(shader, source);
    gl.compileShader(shader);
    if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
        const log = gl.getShaderInfoLog(shader);
        gl.deleteShader(shader);
        throw new Error(`Shader compile error:\n${log}`);
    }
    return shader;
}

function createProgram(gl, vertSrc, fragSrc) {
    const vert = compileShader(gl, gl.VERTEX_SHADER, vertSrc);
    const frag = compileShader(gl, gl.FRAGMENT_SHADER, fragSrc);

    const program = gl.createProgram();
    gl.attachShader(program, vert);
    gl.attachShader(program, frag);
    gl.linkProgram(program);

    if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
        const log = gl.getProgramInfoLog(program);
        gl.deleteProgram(program);
        throw new Error(`Program link error:\n${log}`);
    }
    return program;
}

function createFullscreenQuad(gl) {
    const vertices = new Float32Array([
        -1, -1, 1, -1, -1, 1,
        -1, 1, 1, -1, 1, 1,
    ]);

    const vao = gl.createVertexArray();
    gl.bindVertexArray(vao);

    const vbo = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, vbo);
    gl.bufferData(gl.ARRAY_BUFFER, vertices, gl.STATIC_DRAW);

    gl.enableVertexAttribArray(0);
    gl.vertexAttribPointer(0, 2, gl.FLOAT, false, 0, 0);

    gl.bindVertexArray(null);
    return vao;
}

// --- Ping-pong FBO helpers ---

function createFBO(gl, w, h) {
    const tex = gl.createTexture();
    gl.bindTexture(gl.TEXTURE_2D, tex);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA32F, w, h, 0, gl.RGBA, gl.FLOAT, null);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);

    const fbo = gl.createFramebuffer();
    gl.bindFramebuffer(gl.FRAMEBUFFER, fbo);
    gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, tex, 0);

    const status = gl.checkFramebufferStatus(gl.FRAMEBUFFER);
    if (status !== gl.FRAMEBUFFER_COMPLETE) {
        console.error("Framebuffer incomplete:", status);
    }

    // Clear to zero
    gl.clearColor(0, 0, 0, 0);
    gl.clear(gl.COLOR_BUFFER_BIT);

    gl.bindFramebuffer(gl.FRAMEBUFFER, null);

    return { fbo, tex };
}

function createPingPong(gl, w, h) {
    return {
        read: createFBO(gl, w, h),
        write: createFBO(gl, w, h),
        swap() {
            const tmp = this.read;
            this.read = this.write;
            this.write = tmp;
        },
    };
}

function destroyPingPong(gl, pp) {
    gl.deleteTexture(pp.read.tex);
    gl.deleteFramebuffer(pp.read.fbo);
    gl.deleteTexture(pp.write.tex);
    gl.deleteFramebuffer(pp.write.fbo);
}

// --- Main ---

async function main() {
    const canvas = document.getElementById("glcanvas");
    const gl = canvas.getContext("webgl2");
    if (!gl) {
        document.body.textContent = "WebGL 2 is not supported by your browser.";
        return;
    }

    // Require float texture rendering
    const extFloat = gl.getExtension("EXT_color_buffer_float");
    if (!extFloat) {
        document.body.textContent = "EXT_color_buffer_float not supported.";
        return;
    }

    // Load shaders
    const [vertSrc, fragASrc, fragBSrc, fragCSrc, fragDSrc, fragImgSrc] = await Promise.all([
        loadShader("shaders/vertex.glsl"),
        loadShader("shaders/bufferA.glsl"),
        loadShader("shaders/bufferB.glsl"),
        loadShader("shaders/bufferC.glsl"),
        loadShader("shaders/bufferD.glsl"),
        loadShader("shaders/fragment.glsl"),
    ]);

    // Compile programs
    const progA = createProgram(gl, vertSrc, fragASrc);
    const progB = createProgram(gl, vertSrc, fragBSrc);
    const progC = createProgram(gl, vertSrc, fragCSrc);
    const progD = createProgram(gl, vertSrc, fragDSrc);
    const progImg = createProgram(gl, vertSrc, fragImgSrc);

    // Uniform locations
    function getUniforms(prog) {
        return {
            u_resolution: gl.getUniformLocation(prog, "u_resolution"),
            u_time: gl.getUniformLocation(prog, "u_time"),
            u_mouse: gl.getUniformLocation(prog, "u_mouse"),
            u_frame: gl.getUniformLocation(prog, "u_frame"),
            u_buffer: gl.getUniformLocation(prog, "u_buffer"),
        };
    }
    const uA = getUniforms(progA);
    const uB = getUniforms(progB);
    const uC = getUniforms(progC);
    const uD = getUniforms(progD);
    const uImg = getUniforms(progImg);

    const quad = createFullscreenQuad(gl);

    // Mouse state (ShaderToy convention: z > 0 when pressed)
    const mouse = { x: 0, y: 0, down: false };
    canvas.addEventListener("mousemove", (e) => {
        const rect = canvas.getBoundingClientRect();
        const dpr = window.devicePixelRatio || 1;
        mouse.x = (e.clientX - rect.left) * dpr;
        mouse.y = (canvas.height - (e.clientY - rect.top) * dpr); // flip Y
    });
    canvas.addEventListener("mousedown", () => { mouse.down = true; });
    canvas.addEventListener("mouseup", () => { mouse.down = false; });
    canvas.addEventListener("mouseleave", () => { mouse.down = false; });

    // Touch support
    canvas.addEventListener("touchstart", (e) => {
        e.preventDefault();
        mouse.down = true;
        const t = e.touches[0];
        const rect = canvas.getBoundingClientRect();
        const dpr = window.devicePixelRatio || 1;
        mouse.x = (t.clientX - rect.left) * dpr;
        mouse.y = (canvas.height - (t.clientY - rect.top) * dpr);
    }, { passive: false });
    canvas.addEventListener("touchmove", (e) => {
        e.preventDefault();
        const t = e.touches[0];
        const rect = canvas.getBoundingClientRect();
        const dpr = window.devicePixelRatio || 1;
        mouse.x = (t.clientX - rect.left) * dpr;
        mouse.y = (canvas.height - (t.clientY - rect.top) * dpr);
    }, { passive: false });
    canvas.addEventListener("touchend", () => { mouse.down = false; });

    // FBO management
    let w = 0, h = 0;
    let ppA, ppB, ppC, ppD;

    function ensureFBOs() {
        const dpr = window.devicePixelRatio || 1;
        const newW = Math.round(canvas.clientWidth * dpr);
        const newH = Math.round(canvas.clientHeight * dpr);
        if (newW !== w || newH !== h) {
            w = newW;
            h = newH;
            canvas.width = w;
            canvas.height = h;

            if (ppA) {
                destroyPingPong(gl, ppA);
                destroyPingPong(gl, ppB);
                destroyPingPong(gl, ppC);
                destroyPingPong(gl, ppD);
            }
            ppA = createPingPong(gl, w, h);
            ppB = createPingPong(gl, w, h);
            ppC = createPingPong(gl, w, h);
            ppD = createPingPong(gl, w, h);

            frameCount = 0; // reset sim on resize
        }
    }

    // Helper to run a buffer pass
    function renderPass(prog, uniforms, inputTex, outputFBO, time) {
        gl.bindFramebuffer(gl.FRAMEBUFFER, outputFBO);
        gl.viewport(0, 0, w, h);
        gl.useProgram(prog);

        gl.activeTexture(gl.TEXTURE0);
        gl.bindTexture(gl.TEXTURE_2D, inputTex);
        if (uniforms.u_buffer !== null) gl.uniform1i(uniforms.u_buffer, 0);
        if (uniforms.u_resolution !== null) gl.uniform2f(uniforms.u_resolution, w, h);
        if (uniforms.u_time !== null) gl.uniform1f(uniforms.u_time, time);
        if (uniforms.u_mouse !== null) gl.uniform4f(uniforms.u_mouse, mouse.x, mouse.y, mouse.down ? 1.0 : 0.0, 0.0);
        if (uniforms.u_frame !== null) gl.uniform1i(uniforms.u_frame, frameCount);

        gl.bindVertexArray(quad);
        gl.drawArrays(gl.TRIANGLES, 0, 6);
    }

    let frameCount = 0;
    let startTime = performance.now();
    console.log("Fluid sim initialized. Canvas:", w, "x", h);

    function frame() {
        ensureFBOs();

        const time = (performance.now() - startTime) * 0.001;

        // Pass 1: Buffer A (Forces + gravity) — reads C's previous frame output
        renderPass(progA, uA, ppC.read.tex, ppA.write.fbo, time);
        ppA.swap();

        // Pass 2: Buffer B (Advect, density-adaptive) — reads A's current output
        renderPass(progB, uB, ppA.read.tex, ppB.write.fbo, time);
        ppB.swap();

        // Pass 3: Buffer C (Forces, no gravity) — reads B's current output
        renderPass(progC, uC, ppB.read.tex, ppC.write.fbo, time);
        ppC.swap();

        // Pass 4: Buffer D (Advect, simple) — reads C's current output
        renderPass(progD, uD, ppC.read.tex, ppD.write.fbo, time);
        ppD.swap();

        // Pass 5: Image — reads A's current output → screen
        renderPass(progImg, uImg, ppA.read.tex, null, time);
        gl.viewport(0, 0, w, h); // ensure viewport for screen

        frameCount++;
        requestAnimationFrame(frame);
    }

    requestAnimationFrame(frame);
}

main();
