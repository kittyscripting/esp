const sdk = @import("sdk");

const boxFull: u32 = 1;
const boxCorner: u32 = 2;
const hitboxFull: u32 = 0;
const hitboxWireframe: u32 = 1;

const visuals = sdk.Settings("ESP Visuals", struct {
    enabled: bool = true,
    renderAllies: bool = false,
    renderObjects: bool = false,
    showBacktrack: bool = false,
    bodyColor: u32 = 0x4DFF0000,
    criticalColor: u32 = 0x4DFFFF00,
    boxColor: u32 = 0xB3FF0000,
    visibleBodyColor: u32 = 0x4DFF8C00,
    visibleCriticalColor: u32 = 0x4DFFFF00,
    visibleBoxColor: u32 = 0xB3FF8C00,
    allyBodyColor: u32 = 0x4D00FF00,
    allyCriticalColor: u32 = 0x4D00FFFF,
    allyBoxColor: u32 = 0xB300FF00,
    objectColor: u32 = 0xB38000FF,
    width: f32 = 2.0,
    boxType: u32 = boxFull,
    hitboxType: u32 = hitboxFull,
}, .{
    .enabled = .{ .display_name = "Enabled" },
    .renderAllies = .{ .display_name = "Render Allies" },
    .renderObjects = .{ .display_name = "Render Objects" },
    .showBacktrack = .{ .display_name = "Show Backtrack" },
    .bodyColor = .{ .display_name = "Body Color", .control = "color" },
    .criticalColor = .{ .display_name = "Critical Color", .control = "color" },
    .boxColor = .{ .display_name = "Box Color", .control = "color" },
    .visibleBodyColor = .{ .display_name = "Visible Body Color", .control = "color" },
    .visibleCriticalColor = .{ .display_name = "Visible Critical Color", .control = "color" },
    .visibleBoxColor = .{ .display_name = "Visible Box Color", .control = "color" },
    .allyBodyColor = .{ .display_name = "Ally Body Color", .control = "color" },
    .allyCriticalColor = .{ .display_name = "Ally Critical Color", .control = "color" },
    .allyBoxColor = .{ .display_name = "Ally Box Color", .control = "color" },
    .objectColor = .{ .display_name = "Object Color", .control = "color" },
    .width = .{ .display_name = "Width", .control = "slider", .min = 0.5, .max = 10.0 },
    .boxType = .{ .display_name = "Box Type", .control = "multi", .options = .{ "Off", "Full", "Corner" } },
    .hitboxType = .{ .display_name = "Hitbox", .control = "multi", .options = .{ "Full", "Wireframe", "None" } },
});
const minProjectedHeight: f32 = 2.0;

const ScreenBox = struct {
    x: f32,
    y: f32,
    w: f32,
    h: f32,
};

const ScreenBounds = struct {
    minX: f32 = 0,
    minY: f32 = 0,
    maxX: f32 = 0,
    maxY: f32 = 0,
    count: usize = 0,

    fn include(self: *ScreenBounds, p: sdk.Vec2) void {
        if (self.count == 0) {
            self.minX = p.x;
            self.maxX = p.x;
            self.minY = p.y;
            self.maxY = p.y;
        } else {
            self.minX = @min(self.minX, p.x);
            self.maxX = @max(self.maxX, p.x);
            self.minY = @min(self.minY, p.y);
            self.maxY = @max(self.maxY, p.y);
        }
        self.count += 1;
    }

    fn box(self: ScreenBounds) ?ScreenBox {
        if (self.count < 2) return null;
        const w = self.maxX - self.minX;
        const h = self.maxY - self.minY;
        if (w <= 1.0 or h <= minProjectedHeight) return null;
        return .{ .x = self.minX, .y = self.minY, .w = w, .h = h };
    }
};

fn includeProjected(bounds: *ScreenBounds, pos: sdk.Vec3) void {
    if (sdk.camera.w2s(pos)) |p| bounds.include(p);
}

fn geometryBox(actor: *const sdk.Actor, offset: sdk.Vec3) ?ScreenBox {
    if (!sdk.helpers.hitboxes.hasUsableHitboxes(actor, false)) return null;
    var bounds = ScreenBounds{};

    if (actor.hitboxes) |hitboxes| {
        for (hitboxes.capsules) |capsule| {
            includeProjected(&bounds, capsule.shape.a.add(offset));
            includeProjected(&bounds, capsule.shape.b.add(offset));
        }
        for (hitboxes.spheres) |sphere| includeProjected(&bounds, sphere.shape.center.add(offset));
        for (hitboxes.boxes) |box| {
            const corners = sdk.helpers.hitboxes.boxCorners(box.shape);
            for (corners) |corner| {
                includeProjected(&bounds, corner.add(offset));
            }
        }
    }

    return bounds.box();
}

fn visualColor(color: u32) i32 {
    return @bitCast(sdk.util.argbToHost(color));
}

fn originOffset(actor: *const sdk.Actor) sdk.Vec3 {
    if (!visuals.data.showBacktrack or actor.transform_history.len == 0) return .{};
    return actor.transform_history[0].transform.position.sub(actor.transform.position);
}

fn drawHitboxes(actor: *const sdk.Actor, offset: sdk.Vec3, color: i32, criticalColor: i32) void {
    const hitboxes = actor.hitboxes orelse return;
    switch (visuals.data.hitboxType) {
        hitboxFull => {
            for (hitboxes.capsules) |capsule| {
                const c = if (capsule.critical) criticalColor else color;
                sdk.render.drawCapsule3D(capsule.shape.a.add(offset), capsule.shape.b.add(offset), capsule.shape.radius, c);
            }
            for (hitboxes.spheres) |sphere| {
                const c = if (sphere.critical) criticalColor else color;
                sdk.render.drawSphere3D(sphere.shape.center.add(offset), sphere.shape.radius, c);
            }
            for (hitboxes.boxes) |box| {
                const c = if (box.critical) criticalColor else color;
                sdk.render.drawBox3D(box.shape.center.add(offset), box.shape.half_extents, box.shape.rotation, c);
            }
        },
        hitboxWireframe => {
            for (hitboxes.capsules) |capsule| {
                const c = if (capsule.critical) criticalColor else color;
                sdk.render.drawWireCapsule3D(capsule.shape.a.add(offset), capsule.shape.b.add(offset), capsule.shape.radius, c);
            }
            for (hitboxes.spheres) |sphere| {
                const c = if (sphere.critical) criticalColor else color;
                sdk.render.drawWireSphere3D(sphere.shape.center.add(offset), sphere.shape.radius, c);
            }
            for (hitboxes.boxes) |box| {
                const c = if (box.critical) criticalColor else color;
                sdk.render.drawBox3DWireframe(box.shape.center.add(offset), box.shape.half_extents, box.shape.rotation, c);
            }
        },
        else => {},
    }
}

fn actorBox(actor: *const sdk.Actor, offset: sdk.Vec3) ?ScreenBox {
    return geometryBox(actor, offset);
}

fn drawCornerBox(box: ScreenBox, color: i32, width: f32) void {
    const t = sdk.clampf(width, 0.5, 10.0);
    const cornerW = @max(box.w * 0.25, t);
    const cornerH = @max(box.h * 0.25, t);
    const right = box.x + box.w;
    const bottom = box.y + box.h;

    sdk.render.drawFilledRect(box.x, box.y, cornerW, t, color);
    sdk.render.drawFilledRect(box.x, box.y, t, cornerH, color);

    sdk.render.drawFilledRect(right - cornerW, box.y, cornerW, t, color);
    sdk.render.drawFilledRect(right - t, box.y, t, cornerH, color);

    sdk.render.drawFilledRect(box.x, bottom - t, cornerW, t, color);
    sdk.render.drawFilledRect(box.x, bottom - cornerH, t, cornerH, color);

    sdk.render.drawFilledRect(right - cornerW, bottom - t, cornerW, t, color);
    sdk.render.drawFilledRect(right - t, bottom - cornerH, t, cornerH, color);
}

fn drawBox(box: ScreenBox, color: i32, width: f32) void {
    switch (visuals.data.boxType) {
        boxFull => sdk.render.drawRect(box.x, box.y, box.w, box.h, color, width),
        boxCorner => drawCornerBox(box, color, width),
        else => {},
    }
}

fn shouldRenderActor(actor: *const sdk.Actor) bool {
    return (actor.max_health <= 0.0 or actor.health > 0.0) and !actor.is_invulnerable;
}

export fn onFrame() void {
    if (!sdk.camera.active()) return;
    if (!visuals.data.enabled) return;

    const vp = sdk.render.viewport();
    if (vp.x <= 0.0 or vp.y <= 0.0) return;

    const d = visuals.data;
    const enemyShown = alpha(d.bodyColor) > 0 or alpha(d.criticalColor) > 0 or alpha(d.boxColor) > 0 or
        alpha(d.visibleBodyColor) > 0 or alpha(d.visibleCriticalColor) > 0 or alpha(d.visibleBoxColor) > 0;
    const alliesShown = d.renderAllies and (alpha(d.allyBodyColor) > 0 or alpha(d.allyCriticalColor) > 0 or alpha(d.allyBoxColor) > 0);
    const objectsShown = d.renderObjects and alpha(d.objectColor) > 0;
    if (!enemyShown and !alliesShown and !objectsShown) return;

    const width = sdk.clampf(d.width, 0.5, 10.0);
    for (sdk.actors()) |*actor| {
        if (!shouldRenderActor(actor)) continue;
        if (actor.team == .ally and !d.renderAllies) continue;
        if (actor.kind != .player and !d.renderObjects) continue;
        const p = paletteFor(actor);
        const offset = originOffset(actor);

        if (alpha(p.box) > 0) {
            if (actorBox(actor, offset)) |box| drawBox(box, visualColor(p.box), width);
        }
        if (alpha(p.body) > 0 or alpha(p.critical) > 0)
            drawHitboxes(actor, offset, visualColor(p.body), visualColor(p.critical));
    }
}

const Palette = struct { body: u32, critical: u32, box: u32 };

fn paletteFor(actor: *const sdk.Actor) Palette {
    const d = visuals.data;
    if (actor.kind != .player) return .{ .body = d.objectColor, .critical = d.objectColor, .box = d.objectColor };
    if (actor.team == .ally) return .{ .body = d.allyBodyColor, .critical = d.allyCriticalColor, .box = d.allyBoxColor };
    if (actor.is_visible) return .{ .body = d.visibleBodyColor, .critical = d.visibleCriticalColor, .box = d.visibleBoxColor };
    return .{ .body = d.bodyColor, .critical = d.criticalColor, .box = d.boxColor };
}

fn alpha(color: u32) u32 {
    return (color >> 24) & 0xFF;
}

export fn onTick() void {}
