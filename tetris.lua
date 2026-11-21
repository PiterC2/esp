
local solaros = require("solaros")
local gfx = solaros.gfx
local tui = solaros.tui

local W, H = 320, 240
local COLS, ROWS = 10, 18
local CELL = 10
local BX, BY = 12, 34

local colors = {
    gfx.rgb(0, 220, 255),
    gfx.rgb(255, 210, 0),
    gfx.rgb(180, 70, 255),
    gfx.rgb(0, 220, 100),
    gfx.rgb(255, 80, 80),
    gfx.rgb(60, 110, 255),
    gfx.rgb(255, 140, 20)
}

local shapes = {
    {{0,1},{1,1},{2,1},{3,1}},
    {{0,0},{1,0},{0,1},{1,1}},
    {{1,0},{0,1},{1,1},{2,1}},
    {{1,0},{2,0},{0,1},{1,1}},
    {{0,0},{1,0},{1,1},{2,1}},
    {{0,0},{0,1},{1,1},{2,1}},
    {{2,0},{0,1},{1,1},{2,1}}
}

local board
local current
local score
local lines
local gameover

local function new_board()
    board = {}
    for y = 1, ROWS do
        board[y] = {}
        for x = 1, COLS do
            board[y][x] = 0
        end
    end
end

local function spawn()
    local id = math.random(1, #shapes)
    current = {
        cells = shapes[id],
        color = id,
        x = 3,
        y = 0
    }

    for _, p in ipairs(current.cells) do
        local x = current.x + p[1]
        local y = current.y + p[2]
        if y >= 0 and y < ROWS then
            if board[y + 1][x + 1] ~= 0 then
                gameover = true
            end
        end
    end
end

local function collision(px, py, cells)
    for _, p in ipairs(cells) do
        local x = px + p[1]
        local y = py + p[2]

        if x < 0 or x >= COLS or y >= ROWS then
            return true
        end

        if y >= 0 and board[y + 1][x + 1] ~= 0 then
            return true
        end
    end
    return false
end

local function rotate()
    local rotated = {}

    for _, p in ipairs(current.cells) do
        rotated[#rotated + 1] = {3 - p[2], p[1]}
    end

    if not collision(current.x, current.y, rotated) then
        current.cells = rotated
    end
end

local function lock_piece()
    for _, p in ipairs(current.cells) do
        local x = current.x + p[1]
        local y = current.y + p[2]

        if y >= 0 and y < ROWS then
            board[y + 1][x + 1] = current.color
        end
    end

    local cleared = 0

    for y = ROWS, 1, -1 do
        local full = true

        for x = 1, COLS do
            if board[y][x] == 0 then
                full = false
                break
            end
        end

        if full then
            table.remove(board, y)
            local row = {}
            for x = 1, COLS do
                row[x] = 0
            end
            table.insert(board, 1, row)
            cleared = cleared + 1
            y = y + 1
        end
    end

    if cleared > 0 then
        local points = {0, 100, 300, 500, 800}
        score = score + points[cleared + 1]
        lines = lines + cleared
    end

    spawn()
end

local function drop()
    if not collision(current.x, current.y + 1, current.cells) then
        current.y = current.y + 1
    else
        lock_piece()
    end
end

local function draw_cell(x, y, color)
    local px = BX + x * CELL
    local py = BY + y * CELL

    gfx.color(color)
    gfx.fill_rect(px + 1, py + 1, CELL - 2, CELL - 2)
end

local function draw()
    gfx.clear(gfx.rgb(10, 12, 22))

    gfx.color(gfx.rgb(0, 220, 255))
    gfx.font(gfx.FONT_BOLD)
    gfx.text(12, 21, "SOLAR TETRIS")

    gfx.color(gfx.WHITE)
    gfx.rect(BX - 1, BY - 1, COLS * CELL + 2, ROWS * CELL + 2)

    for y = 1, ROWS do
        for x = 1, COLS do
            local id = board[y][x]
            if id ~= 0 then
                draw_cell(x - 1, y - 1, colors[id])
            end
        end
    end

    if current then
        for _, p in ipairs(current.cells) do
            local x = current.x + p[1]
            local y = current.y + p[2]
            if y >= 0 then
                draw_cell(x, y, colors[current.color])
            end
        end
    end

    gfx.font(gfx.FONT_SMALL)
    gfx.color(gfx.WHITE)
    gfx.text(128, 55, "SCORE")
    gfx.text(128, 72, tostring(score))
    gfx.text(128, 105, "LINES")
    gfx.text(128, 122, tostring(lines))

    gfx.color(gfx.rgb(0, 220, 255))
    gfx.text(128, 165, "CONTROLS")

    gfx.color(gfx.WHITE)
    gfx.text(128, 180, "Arrows: Move")
    gfx.text(128, 195, "Up: Rotate")
    gfx.text(128, 210, "Down: Drop")

    if gameover then
        gfx.color(gfx.rgb(255, 70, 70))
        gfx.font(gfx.FONT_BOLD)
        gfx.text(25, 115, "GAME OVER")
        gfx.font(gfx.FONT_SMALL)
        gfx.color(gfx.WHITE)
        gfx.text(25, 135, "Press R to restart")
    end

    gfx.present()
end

local function restart()
    new_board()
    score = 0
    lines = 0
    gameover = false
    spawn()
end

local function run()
    gfx.begin("lcd0")

    local ok, err = pcall(function()
        math.randomseed(solaros.time.uptime())
        restart()
        local elapsed = 0
        local interval = 500

        while not solaros.should_exit() do
            local key = tui.getch(20)

            if key == tui.KEY_ESCAPE then
                break
            end

            if gameover then
                if key == string.byte("r") or
                   key == string.byte("R") then
                    restart()
                    elapsed = 0
                end
            else
                if key == tui.KEY_LEFT then
                    if not collision(current.x - 1,
                        current.y, current.cells) then
                        current.x = current.x - 1
                    end

                elseif key == tui.KEY_RIGHT then
                    if not collision(current.x + 1,
                        current.y, current.cells) then
                        current.x = current.x + 1
                    end

                elseif key == tui.KEY_UP then
                    rotate()

                elseif key == tui.KEY_DOWN then
                    drop()
                    elapsed = 0

                elseif key == string.byte(" ") then
                    while not collision(current.x,
                        current.y + 1, current.cells) do
                        current.y = current.y + 1
                    end
                    drop()
                    elapsed = 0
                end

                elapsed = elapsed + 20

                interval = math.max(100, 500 - lines * 20)

                if elapsed >= interval then
                    drop()
                    elapsed = 0
                end
            end

            draw()
        end
    end)

    gfx["end"]()

    if not ok then
        error(err)
    end
end

run()
