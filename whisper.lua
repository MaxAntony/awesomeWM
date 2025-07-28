-- ===================================================================
-- Módulo de Whisper para AwesomeWM
--
-- Características:
--   - Configurable desde rc.lua (modelo, idioma, dispositivo, etc.).
--   - Acción por defecto configurable: copiar al portapapeles o pegar directamente.
--   - Notificaciones de error detalladas y con mayor duración.
--   - Lógica robusta para evitar "race conditions".
--   - Uso de ID de ventana para un pegado fiable.
--   - Funciones separadas para iniciar/detener/pegar.
-- ===================================================================

local awful = require('awful')
local naughty = require('naughty')
local gears = require('gears')

local whisper = {
  -- Archivos temporales
  audio_file = '/tmp/whisper_awesomewm_audio.wav',
  pid_file = '/tmp/whisper_awesomewm_pid',

  -- Estado interno
  output_text = '',
  recording_pid = nil,
  last_focused_window_id = nil,
}

-- Tabla de configuración con valores por defecto.
-- Estos serán sobrescritos por la configuración en rc.lua.
whisper.config = {
  -- El comando a ejecutar. Cambia esto si usas un venv o una ruta específica.
  command = 'whisper',

  -- Modelo a usar. Opciones comunes: tiny, base, small, medium, large.
  -- tiny y base son más rápidos, medium y large son más precisos.
  model = 'base',

  -- Dispositivo de cómputo. Usa 'cuda' si tienes una GPU NVIDIA con CUDA configurado.
  -- Usa 'cpu' si no.
  device = 'cpu',

  -- Idioma del audio. 'es' para español.
  language = 'es',

  -- Acción a realizar después de transcribir.
  -- "clipboard": Copia el texto al portapapeles. (Requiere 'xclip')
  -- "paste": Pega el texto directamente en la ventana activa al iniciar.
  action = 'clipboard',

  -- Duración de las notificaciones en segundos.
  timeout_info = 5,
  timeout_error = 20, -- Más tiempo para leer los errores.
}

-- Función interna para mostrar notificaciones.
local function show_notification(title, text, timeout)
  naughty.notify({
    title = title,
    text = text,
    timeout = timeout or whisper.config.timeout_info,
    width = 400,
  })
end

-- Función interna para mostrar errores de forma destacada.
local function show_error_notification(text)
  naughty.notify({
    title = 'Whisper - Error de Transcripción',
    text = text,
    timeout = whisper.config.timeout_error,
    urgency = 'critical',
  })
end

-- Guarda el ID de la ventana que tiene el foco. Se llama antes de grabar.
function whisper.get_focused_window_id()
  awful.spawn.easy_async_with_shell('xdotool getwindowfocus', function(stdout)
    if stdout and stdout:match('%d+') then
      whisper.last_focused_window_id = stdout:match('(%d+)')
    else
      whisper.last_focused_window_id = nil
    end
  end)
end

-- Iniciar grabación
function whisper.start_recording()
  if whisper.recording_pid then
    show_notification('Grabación', 'Ya hay una grabación en curso.')
    return
  end

  whisper.get_focused_window_id() -- Guardamos el ID de la ventana actual

  -- Usamos & y echo $! para obtener el PID del proceso en segundo plano.
  local cmd = string.format('(arecord -q -f cd -t wav %s & echo $! > %s)', whisper.audio_file, whisper.pid_file)
  awful.spawn.with_shell(cmd)

  -- Esperamos un instante para que se escriba el archivo PID.
  gears.timer.start_new(0.2, function()
    awful.spawn.easy_async_with_shell('cat ' .. whisper.pid_file, function(stdout)
      local pid = tonumber(stdout)
      if pid then
        whisper.recording_pid = pid
        show_notification('Grabación iniciada', 'Grabando audio... Presiona tu atajo para detener.')
      else
        show_notification('Error', 'No se pudo iniciar la grabación.', whisper.config.timeout_error)
      end
    end)
  end)
end

-- Transcribir el audio grabado.
function whisper.transcribe_audio()
  show_notification('Procesando', 'Transcribiendo audio, por favor espera...')

  -- Construye el comando de Whisper con las opciones de configuración.
  local transcription_output_dir = '/tmp'
  local transcription_file_path = transcription_output_dir .. '/' .. whisper.audio_file:match('([^/]+)$'):gsub('%.wav$', '.txt')

  local cmd = string.format(
    '%s "%s" --model %s --device %s --language %s --output_format txt --output_dir %s',
    whisper.config.command,
    whisper.audio_file,
    whisper.config.model,
    whisper.config.device,
    whisper.config.language,
    transcription_output_dir
  )

  -- Ejecutamos whisper y capturamos stdout y stderr.
  awful.spawn.easy_async_with_shell(cmd, function(stdout, stderr, reason, exit_code)
    -- Si el código de salida no es 0, hubo un error.
    if exit_code ~= 0 then
      show_error_notification('El comando de Whisper falló:\n' .. (stderr or 'No hay detalles del error.'))
      return
    end

    -- Leemos el archivo de transcripción generado por Whisper.
    local f = io.open(transcription_file_path, 'r')
    if not f then
      show_error_notification('No se pudo encontrar el archivo de transcripción:\n' .. transcription_file_path)
      return
    end

    local text = f:read('*all'):gsub('^%s*', ''):gsub('%s*$', '') -- Leemos y limpiamos espacios.
    f:close()
    awful.spawn.with_shell('rm ' .. transcription_file_path) -- Limpiamos el archivo.

    if not text or #text == 0 then
      show_notification('Transcripción', 'No se pudo transcribir ningún texto.')
      return
    end

    whisper.output_text = text -- Guardamos el texto por si se quiere pegar después.

    -- Realizamos la acción configurada.
    if whisper.config.action == 'clipboard' then
      local pipe = io.popen('xclip -selection clipboard', 'w')
      if pipe then
        pipe:write(text)
        pipe:close()
        show_notification('¡Copiado al portapapeles!', text)
      else
        show_error_notification("Error al copiar. ¿Está 'xclip' instalado?")
      end
    elseif whisper.config.action == 'paste' then
      whisper.paste_last_transcription()
    else
      show_notification('Transcripción completada', text)
    end
  end)
end

-- Detener grabación
function whisper.stop_recording()
  if not whisper.recording_pid then
    show_notification('Grabación', 'No hay ninguna grabación en curso.')
    return
  end

  awful.spawn.easy_async_with_shell('kill ' .. whisper.recording_pid, function()
    whisper.recording_pid = nil
    show_notification('Grabación detenida', 'Grabación finalizada. Iniciando transcripción.')
    whisper.transcribe_audio()
    -- Limpieza de archivos
    awful.spawn.with_shell('rm ' .. whisper.audio_file .. ' ' .. whisper.pid_file)
  end)
end

-- Pega la última transcripción en la ventana que estaba activa.
function whisper.paste_last_transcription()
  if not whisper.output_text or #whisper.output_text == 0 then
    show_notification('Pegar', 'No hay texto transcrito para pegar.')
    return
  end

  if not whisper.last_focused_window_id then
    show_error_notification('No se encontró una ventana de destino para pegar.')
    return
  end

  -- Escapamos el texto de forma segura para pasarlo a la línea de comandos.
  local escaped_text = "'" .. whisper.output_text:gsub("'", "'\\''") .. "'"
  local cmd = string.format('xdotool type --window %s %s', whisper.last_focused_window_id, escaped_text)

  awful.spawn.easy_async_with_shell(cmd, function() show_notification('Texto Pegado', whisper.output_text) end)
end

-- Función de Setup para configurar el módulo desde rc.lua
function whisper.setup(user_config)
  -- gears.table.join es la forma correcta de fusionar tablas de configuración.
  whisper.config = gears.table.join(whisper.config, user_config or {})
end

return whisper
