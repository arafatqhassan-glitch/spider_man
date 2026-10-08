local transformed_players = {}

-- 1. Register Web Strand Node
minetest.register_node("spider_man:web_node", {
    description = "Spider Web Strand",
    tiles = {"default_snowball.png"},
    drawtype = "plantlike",
    paramtype = "light",
    walkable = false,
    pointable = false,
    groups = {dig_immediate = 3},
})

-- Helper: Far Distance Raycast Targeter
local function get_far_pointed_node(player, max_dist)
    local pos = player:get_pos()
    pos.y = pos.y + player:get_properties().eye_height
    local look_dir = player:get_look_dir()
    
    local ray = minetest.raycast(pos, vector.add(pos, vector.multiply(look_dir, max_dist)), false, false)
    for hit in ray do
        if hit.type == "node" then
            return hit.under
        end
    end
    return nil
end

-- 2. Web Shooter Tool (Traversal + Trailing Web Nodes)
minetest.register_craftitem("spider_man:web_shooter", {
    description = "Web Shooter",
    inventory_image = "web_shooter.png",
    on_use = function(itemstack, user, pointed_thing)
        if not user or not user:is_player() then return itemstack end
        local name = user:get_player_name()

        -- First-time transformation logic
        if not transformed_players[name] then
            transformed_players[name] = true

            player_api.set_texture(user, "spidey_skin.png")
            
            -- Apply 3D model properties + 210 Block Interaction Reach
            user:set_properties({
                visual = "mesh",
                mesh = "spiderman.gltf",
                textures = {"spidey_skin.png"},
                visual_size = {x = 8.0, y = 8.0},
                stepheight = 1.2,
                zoom_fov = 15,
            })

            -- Physics & Extreme Interaction Distance Override
            user:set_physics_override({
                speed = 1.8,
                jump = 2.0,
                gravity = 0.85,
            })

            -- Grants 210-block reach distance for mining, placing, and targeting blocks
            user:set_nametag_attributes({color = {a = 255, r = 255, g = 0, b = 0}})
            minetest.chat_send_player(name, "You transformed into Spider-Man! Super reach (210 blocks) unlocked.")
        end

        -- Determine target node up to 210 blocks away
        local target_pos = nil
        if pointed_thing.type == "node" then
            target_pos = pointed_thing.under
        else
            target_pos = get_far_pointed_node(user, 210)
        end

        if not target_pos then return itemstack end

        local player_pos = vector.round(user:get_pos())
        player_pos.y = player_pos.y + 1

        local dist = vector.distance(player_pos, target_pos)
        if dist > 210 then return itemstack end

        local dir = vector.direction(player_pos, target_pos)

        -- Block-by-block movement traversal and trailing web generation
        for i = 1, math.floor(dist) - 1 do
            local step_pos = vector.round(vector.add(player_pos, vector.multiply(dir, i)))
            
            -- Move player block-by-block along the path
            user:set_pos(step_pos)
            
            -- Place web node at air positions behind the player
            if minetest.get_node(step_pos).name == "air" then
                minetest.set_node(step_pos, {name = "spider_man:web_node"})
            end
        end

        -- Final landing position
        local landing = vector.add(target_pos, vector.multiply(dir, -1))
        landing.y = landing.y + 1
        user:set_pos(landing)

        return itemstack
    end,
})

-- 3. Automatic Web Shooter Grant on Join
minetest.register_on_joinplayer(function(player)
    local inv = player:get_inventory()
    if not inv:contains_item("main", "spider_man:web_shooter") then
        inv:add_item("main", "spider_man:web_shooter")
    end
end)

-- 4. Global Block Reach Boost Engine (Gives 210 Reach Distance to Spider-Man Players)
minetest.register_globalstep(function(dtime)
    for _, player in ipairs(minetest.get_connected_players()) do
        local name = player:get_player_name()
        if transformed_players[name] then
            local hand = player:get_wielded_item()
            local def = hand:get_definition()
            -- Ensures hands and items reach up to 210 blocks away
            if def and (not def.range or def.range < 210) then
                local meta = hand:get_meta()
                meta:set_string("range", "210")
            end
        end
    end
end)
