const std = @import("std");

/// State of the Apollo Lunar Module during descent.
pub const LunarLander = struct {
    /// Altitude in miles
    altitude: f64 = 120.0,
    /// Downward speed in miles/second
    velocity: f64 = 1.0,
    /// Total lander mass in lbs
    total_weight: f64 = 32500.0,
    /// Empty lander mass in lbs (total_weight - empty_weight = remaining fuel)
    empty_weight: f64 = 16500.0,
    /// Acceleration due to gravity in miles/second^2
    gravity: f64 = 0.001,
    /// Thrust per pound of fuel burned
    thrust_coeff: f64 = 1.8,
    /// Total elapsed time in seconds
    elapsed_time: f64 = 0.0,
    /// Fuel burn rate for current turn in lbs/second
    fuel_rate: f64 = 0.0,
    /// Time remaining in current 10-second turn
    time_rem_turn: f64 = 0.0,
    /// Intermediate altitude (calculated during physics integration)
    inter_altitude: f64 = 0.0,
    /// Intermediate velocity (calculated during physics integration)
    inter_velocity: f64 = 0.0,

    /// Remaining fuel in lbs.
    pub fn fuelRemaining(self: LunarLander) f64 {
        return self.total_weight - self.empty_weight;
    }

    /// Velocity in miles per hour.
    pub fn velocityMph(self: LunarLander) f64 {
        return 3600.0 * self.velocity;
    }

    /// Altitude split into miles and feet.
    pub fn altitudeMilesAndFeet(self: LunarLander) struct { miles: f64, feet: f64 } {
        const miles = @trunc(self.altitude);
        const feet = 5280.0 * (self.altitude - miles);
        return .{ .miles = miles, .feet = feet };
    }

    /// Updates intermediate velocity and altitude based on current thrust rate and duration `dt`.
    pub fn applyThrust(self: *LunarLander, dt: f64) void {
        const Q = dt * self.fuel_rate / self.total_weight;
        const Q_2 = Q * Q;
        const Q_3 = Q_2 * Q;
        const Q_4 = Q_3 * Q;
        const Q_5 = Q_4 * Q;

        self.inter_velocity = self.velocity + self.gravity * dt + self.thrust_coeff * (-Q - Q_2 / 2.0 - Q_3 / 3.0 - Q_4 / 4.0 - Q_5 / 5.0);
        self.inter_altitude = self.altitude - self.gravity * dt * dt / 2.0 - self.velocity * dt + self.thrust_coeff * dt * (Q / 2.0 + Q_2 / 6.0 + Q_3 / 12.0 + Q_4 / 20.0 + Q_5 / 30.0);
    }

    /// Advances the lander state by duration `dt`.
    pub fn updateState(self: *LunarLander, dt: f64) void {
        self.elapsed_time += dt;
        self.time_rem_turn -= dt;
        self.total_weight -= dt * self.fuel_rate;
        self.altitude = self.inter_altitude;
        self.velocity = self.inter_velocity;
    }
};

pub const GameIo = struct {
    reader: *std.Io.Reader,
    writer: *std.Io.Writer,
    stderr: *std.Io.Writer,
    echo_input: bool = false,

    pub fn readLine(self: *GameIo) ![]const u8 {
        if (try self.reader.takeDelimiter('\n')) |line| {
            if (self.echo_input) {
                try self.writer.print("{s}\n", .{line});
                try self.writer.flush();
            }
            return line;
        } else {
            try self.stderr.writeAll("\nEND OF INPUT\n");
            try self.stderr.flush();
            std.process.exit(1);
        }
    }

    pub fn acceptDouble(self: *GameIo) !f64 {
        const line = try self.readLine();
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (trimmed.len == 0) return error.InvalidDouble;
        return std.fmt.parseFloat(f64, trimmed) catch error.InvalidDouble;
    }

    pub fn acceptYesNo(self: *GameIo) !bool {
        while (true) {
            try self.writer.writeAll("(ANS. YES OR NO):");
            try self.writer.flush();
            const line = try self.readLine();
            const trimmed = std.mem.trimStart(u8, line, " \t\r");
            if (trimmed.len > 0) {
                switch (trimmed[0]) {
                    'y', 'Y' => return true,
                    'n', 'N' => return false,
                    else => {},
                }
            }
        }
    }
};

pub fn playGame(game_io: *GameIo) !void {
    var lander = LunarLander{};

    try game_io.writer.writeAll("FIRST RADAR CHECK COMING UP\n\n\n");
    try game_io.writer.writeAll("COMMENCE LANDING PROCEDURE\n");
    try game_io.writer.writeAll("TIME,SECS   ALTITUDE,MILES+FEET   VELOCITY,MPH   FUEL,LBS   FUEL RATE\n");
    try game_io.writer.flush();

    start_turn: while (true) {
        const alt = lander.altitudeMilesAndFeet();
        try game_io.writer.print("{d: >7.0}{d: >16.0}{d: >7.0}{d: >15.2}{d: >12.1}      ", .{
            lander.elapsed_time,
            alt.miles,
            alt.feet,
            lander.velocityMph(),
            lander.fuelRemaining(),
        });

        prompt_for_k: while (true) {
            try game_io.writer.writeAll("K=:");
            try game_io.writer.flush();

            const k_val = game_io.acceptDouble() catch {
                try printInvalidK(game_io);
                continue :prompt_for_k;
            };

            if (k_val < 0.0 or (k_val > 0.0 and k_val < 8.0) or k_val > 200.0) {
                try printInvalidK(game_io);
                continue :prompt_for_k;
            }

            lander.fuel_rate = k_val;
            break :prompt_for_k;
        }

        lander.time_rem_turn = 10.0;

        sim_loop: while (true) {
            if (lander.fuelRemaining() < 0.001) {
                try printFuelOut(&lander, game_io);
                break :start_turn;
            }

            if (lander.time_rem_turn < 0.001) {
                continue :start_turn;
            }

            var S = lander.time_rem_turn;
            if (lander.empty_weight + S * lander.fuel_rate - lander.total_weight > 0.0) {
                S = lander.fuelRemaining() / lander.fuel_rate;
            }

            lander.applyThrust(S);

            if (lander.inter_altitude <= 0.0) {
                loopUntilOnMoon(&lander, S);
                try printOnTheMoon(&lander, game_io);
                break :start_turn;
            }

            if (lander.velocity > 0.0 and lander.inter_velocity < 0.0) {
                while (true) {
                    const W = (1.0 - lander.total_weight * lander.gravity / (lander.thrust_coeff * lander.fuel_rate)) / 2.0;
                    const denom = W + @sqrt(W * W + lander.velocity / lander.thrust_coeff);
                    S = lander.total_weight * lander.velocity / (lander.thrust_coeff * lander.fuel_rate * denom) + 0.05;

                    lander.applyThrust(S);

                    if (lander.inter_altitude <= 0.0) {
                        loopUntilOnMoon(&lander, S);
                        try printOnTheMoon(&lander, game_io);
                        break :start_turn;
                    }

                    lander.updateState(S);

                    if (-lander.inter_velocity < 0.0 or lander.velocity <= 0.0) {
                        continue :sim_loop;
                    }
                }
            }

            lander.updateState(S);
        }
    }
}

fn printInvalidK(game_io: *GameIo) !void {
    try game_io.writer.writeAll("NOT POSSIBLE");
    var i: usize = 0;
    while (i < 51) : (i += 1) {
        try game_io.writer.writeByte('.');
    }
    try game_io.writer.flush();
}

fn loopUntilOnMoon(lander: *LunarLander, initial_S: f64) void {
    var S = initial_S;
    while (S >= 0.005) {
        const disc = lander.velocity * lander.velocity + 2.0 * lander.altitude * (lander.gravity - lander.thrust_coeff * lander.fuel_rate / lander.total_weight);
        S = 2.0 * lander.altitude / (lander.velocity + @sqrt(disc));
        lander.applyThrust(S);
        lander.updateState(S);
    }
}

fn printFuelOut(lander: *LunarLander, game_io: *GameIo) !void {
    try game_io.writer.print("FUEL OUT AT {d: >8.2} SECS\n", .{lander.elapsed_time});
    const S = (@sqrt(lander.velocity * lander.velocity + 2.0 * lander.altitude * lander.gravity) - lander.velocity) / lander.gravity;
    lander.velocity += lander.gravity * S;
    lander.elapsed_time += S;
    try printOnTheMoon(lander, game_io);
}

fn printOnTheMoon(lander: *LunarLander, game_io: *GameIo) !void {
    try game_io.writer.print("ON THE MOON AT {d: >8.2} SECS\n", .{lander.elapsed_time});
    const W = 3600.0 * lander.velocity;
    try game_io.writer.print("IMPACT VELOCITY OF {d: >8.2} M.P.H.\n", .{W});
    try game_io.writer.print("FUEL LEFT: {d: >8.2} LBS\n", .{lander.fuelRemaining()});
    if (W <= 1.0) {
        try game_io.writer.writeAll("PERFECT LANDING !-(LUCKY)\n");
    } else if (W <= 10.0) {
        try game_io.writer.writeAll("GOOD LANDING-(COULD BE BETTER)\n");
    } else if (W <= 22.0) {
        try game_io.writer.writeAll("CONGRATULATIONS ON A POOR LANDING\n");
    } else if (W <= 40.0) {
        try game_io.writer.writeAll("CRAFT DAMAGE. GOOD LUCK\n");
    } else if (W <= 60.0) {
        try game_io.writer.writeAll("CRASH LANDING-YOU'VE 5 HRS OXYGEN\n");
    } else {
        try game_io.writer.writeAll("SORRY,BUT THERE WERE NO SURVIVORS-YOU BLEW IT!\n");
        try game_io.writer.print("IN FACT YOU BLASTED A NEW LUNAR CRATER {d: >8.2} FT. DEEP\n", .{W * 0.277777});
    }
    try game_io.writer.flush();
}

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    var echo = false;
    if (args.len > 1 and std.mem.eql(u8, args[1], "--echo")) {
        echo = true;
    }

    const stdin_file = std.Io.File.stdin();
    const stdout_file = std.Io.File.stdout();
    const stderr_file = std.Io.File.stderr();

    var stdin_buf: [1024]u8 = undefined;
    var stdout_buf: [1024]u8 = undefined;
    var stderr_buf: [1024]u8 = undefined;

    var stdin_reader = stdin_file.reader(init.io, &stdin_buf);
    var stdout_writer = stdout_file.writer(init.io, &stdout_buf);
    var stderr_writer = stderr_file.writer(init.io, &stderr_buf);

    var game_io = GameIo{
        .reader = &stdin_reader.interface,
        .writer = &stdout_writer.interface,
        .stderr = &stderr_writer.interface,
        .echo_input = echo,
    };

    try game_io.writer.writeAll("CONTROL CALLING LUNAR MODULE. MANUAL CONTROL IS NECESSARY\n");
    try game_io.writer.writeAll("YOU MAY RESET FUEL RATE K EACH 10 SECS TO 0 OR ANY VALUE\n");
    try game_io.writer.writeAll("BETWEEN 8 & 200 LBS/SEC. YOU'VE 16000 LBS FUEL. ESTIMATED\n");
    try game_io.writer.writeAll("FREE FALL IMPACT TIME-120 SECS. CAPSULE WEIGHT-32500 LBS\n\n\n");
    try game_io.writer.flush();

    while (true) {
        try playGame(&game_io);

        try game_io.writer.writeAll("\n\n\nTRY AGAIN?\n");
        try game_io.writer.flush();

        const play_again = try game_io.acceptYesNo();
        if (!play_again) break;
    }

    try game_io.writer.writeAll("CONTROL OUT\n\n\n");
    try game_io.writer.flush();
}

test "LunarLander initial state" {
    const lander = LunarLander{};
    try std.testing.expectEqual(120.0, lander.altitude);
    try std.testing.expectEqual(1.0, lander.velocity);
    try std.testing.expectEqual(16000.0, lander.fuelRemaining());
    try std.testing.expectEqual(3600.0, lander.velocityMph());

    const alt = lander.altitudeMilesAndFeet();
    try std.testing.expectEqual(120.0, alt.miles);
    try std.testing.expectEqual(0.0, alt.feet);
}

test "LunarLander free fall acceleration" {
    var lander = LunarLander{ .fuel_rate = 0.0 };
    lander.applyThrust(10.0);
    lander.updateState(10.0);

    try std.testing.expectEqual(10.0, lander.elapsed_time);
    try std.testing.expectEqual(1.01, lander.velocity);
    try std.testing.expectEqual(16000.0, lander.fuelRemaining());
}
