obs           = obslua
source_name   = ""
total_seconds = 0
cur_seconds   = 0

last_text     = ""
stop_text     = ""
running       = false

hotkey_start  = obs.OBS_INVALID_HOTKEY_ID
hotkey_stop   = obs.OBS_INVALID_HOTKEY_ID
hotkey_reset  = obs.OBS_INVALID_HOTKEY_ID

----------------------------------------------------------

function set_time_text()
    local seconds       = math.floor(cur_seconds % 60)
    local total_minutes = math.floor(cur_seconds / 60)
    local minutes       = math.floor(total_minutes % 60)
    local hours         = math.floor(total_minutes / 60)

    local text = string.format("%02d:%02d:%02d", hours, minutes, seconds)

    if cur_seconds <= 0 then
        text = stop_text
    end

    if text ~= last_text then
        local source = obs.obs_get_source_by_name(source_name)
        if source then
            local settings = obs.obs_data_create()
            obs.obs_data_set_string(settings, "text", text)
            obs.obs_source_update(source, settings)
            obs.obs_data_release(settings)
            obs.obs_source_release(source)
        end
    end

    last_text = text
end

----------------------------------------------------------

function timer_callback()
    if not running then return end

    cur_seconds = cur_seconds - 1

    if cur_seconds <= 0 then
        cur_seconds = 0
        running = false
        obs.timer_remove(timer_callback)
    end

    set_time_text()
end

----------------------------------------------------------
-- HOTKEY CALLBACKS
----------------------------------------------------------

function start_timer(pressed)
    if not pressed then return end
    if running then return end

    running = true
    obs.timer_add(timer_callback, 1000)
end

function stop_timer(pressed)
    if not pressed then return end
    if not running then return end

    running = false
    obs.timer_remove(timer_callback)
end

function reset_timer(pressed)
    if not pressed then return end

    running = false
    obs.timer_remove(timer_callback)
    cur_seconds = total_seconds
    set_time_text()
end

----------------------------------------------------------
-- OBS UI
----------------------------------------------------------

function script_properties()
    local props = obs.obs_properties_create()

    obs.obs_properties_add_int(props, "duration", "Duration (minutes)", 1, 100000, 1)

    local p = obs.obs_properties_add_list(
        props, "source", "Text Source",
        obs.OBS_COMBO_TYPE_EDITABLE,
        obs.OBS_COMBO_FORMAT_STRING
    )

    local sources = obs.obs_enum_sources()
    if sources then
        for _, source in ipairs(sources) do
            local id = obs.obs_source_get_unversioned_id(source)
            if id == "text_gdiplus" or id == "text_ft2_source" then
                local name = obs.obs_source_get_name(source)
                obs.obs_property_list_add_string(p, name, name)
            end
        end
    end
    obs.source_list_release(sources)

    obs.obs_properties_add_text(props, "stop_text", "Final Text", obs.OBS_TEXT_DEFAULT)

    return props
end

function script_description()
    return "Countdown timer controlled via hotkeys (Start / Stop / Reset)"
end

----------------------------------------------------------
-- SETTINGS
----------------------------------------------------------

function script_update(settings)
    total_seconds = obs.obs_data_get_int(settings, "duration") * 60
    source_name   = obs.obs_data_get_string(settings, "source")
    stop_text     = obs.obs_data_get_string(settings, "stop_text")

    cur_seconds = total_seconds
    set_time_text()
end

function script_defaults(settings)
    obs.obs_data_set_default_int(settings, "duration", 5)
    obs.obs_data_set_default_string(settings, "stop_text", "Starting Soon")
end

----------------------------------------------------------
-- HOTKEY REGISTRATION
----------------------------------------------------------

function script_save(settings)
    obs.obs_data_set_array(settings, "hk_start", obs.obs_hotkey_save(hotkey_start))
    obs.obs_data_set_array(settings, "hk_stop",  obs.obs_hotkey_save(hotkey_stop))
    obs.obs_data_set_array(settings, "hk_reset", obs.obs_hotkey_save(hotkey_reset))
end

function script_load(settings)
    hotkey_start = obs.obs_hotkey_register_frontend(
        "timer_start", "Countdown Start", start_timer
    )
    hotkey_stop = obs.obs_hotkey_register_frontend(
        "timer_stop", "Countdown Stop", stop_timer
    )
    hotkey_reset = obs.obs_hotkey_register_frontend(
        "timer_reset", "Countdown Reset", reset_timer
    )

    obs.obs_hotkey_load(hotkey_start, obs.obs_data_get_array(settings, "hk_start"))
    obs.obs_hotkey_load(hotkey_stop,  obs.obs_data_get_array(settings, "hk_stop"))
    obs.obs_hotkey_load(hotkey_reset, obs.obs_data_get_array(settings, "hk_reset"))
end
