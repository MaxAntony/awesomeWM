local awful = require('awful')
local naughty = require('naughty')

local whisper = {
  audio_file = '/tmp/whisper_audio.wav',
  transcription_file = '/tmp/whisper_audio.txt',
  output_text = '',
  recording_pid = nil,
  last_focused_window = nil,
}

-- Obtener la ventana enfocada
function whisper.get_focused_window()
  awful.spawn.easy_async_with_shell('xdotool getwindowfocus getwindowname', function(stdout)
    whisper.last_focused_window = stdout:gsub('%s*$', '') -- Elimina espacios finales
  end)
end

-- Iniciar grabación
function whisper.start_recording()
  if whisper.recording_pid then
    naughty.notify({ title = 'Grabación', text = 'Ya está grabando...', timeout = 3 })
    return
  end

  whisper.get_focused_window() -- Guardamos la última ventana en foco

  local cmd = string.format('(arecord -f cd -t wav %s & echo $! > /tmp/whisper_pid)', whisper.audio_file)
  awful.spawn.with_shell(cmd)

  -- Obtener el PID
  awful.spawn.easy_async_with_shell('cat /tmp/whisper_pid', function(stdout)
    local pid = math.tointeger(stdout:match('(%d+)'))
    if pid then
      whisper.recording_pid = pid
      naughty.notify({ title = 'Grabación', text = 'Grabando... Presiona Alt + S para detener', timeout = 5 })
    else
      naughty.notify({ title = 'Error', text = 'No se pudo obtener el PID de la grabación.' })
    end
  end)
end

-- Detener grabación
function whisper.stop_recording()
  if not whisper.recording_pid then
    naughty.notify({ title = 'Grabación', text = 'No hay ninguna grabación en curso.', timeout = 3 })
    return
  end

  awful.spawn.easy_async_with_shell('kill ' .. whisper.recording_pid, function()
    whisper.recording_pid = nil
    naughty.notify({ title = 'Grabación', text = 'Grabación detenida. Procesando...', timeout = 3 })
    whisper.transcribe_audio()
  end)
end

-- Transcribir audio con Whisper
function whisper.transcribe_audio()
  local cmd = string.format('whisper %s --device cuda --model tiny --language es --output_format txt --output_dir /tmp > /dev/null 2>&1', whisper.audio_file)

  awful.spawn.easy_async_with_shell(cmd, function()
    local f = io.open(whisper.transcription_file, 'r')
    if f then
      whisper.output_text = f:read('*all'):gsub('\n', ' ') -- Eliminar saltos de línea
      f:close()

      if #whisper.output_text > 0 then
        whisper.show_notification(whisper.output_text)
        whisper.paste_text()
      else
        whisper.show_notification('Error: No se generó texto en la transcripción.')
      end
    else
      whisper.show_notification('Error en la transcripción')
    end
  end)
end

-- Mostrar notificación con la transcripción
function whisper.show_notification(text) naughty.notify({ title = 'Transcripción', text = text, timeout = 10 }) end

-- Pegar texto en el input activo
function whisper.paste_text()
  if whisper.last_focused_window then
    local escaped_text = whisper.output_text:gsub('"', '\\"') -- Escapar comillas
    local cmd = string.format('xdotool type --window "$(xdotool getwindowfocus)" "%s"', escaped_text)

    awful.spawn.easy_async_with_shell(cmd, function() naughty.notify({ title = 'Texto Pegado', text = whisper.output_text }) end)
  else
    naughty.notify({ title = 'Error', text = 'No se detectó un input en foco.' })
  end
end

return whisper
