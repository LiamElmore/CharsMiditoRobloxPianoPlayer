import mido
import csv

NOTE_NAMES = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B']

# Define Ctrl key mappings (low and high ranges)
LOW_CTRL_KEYS = "1234567890qwert"
LOW_CTRL_BLACK_KEYS = "2570wr"

HIGH_CTRL_KEYS = "yuiopasdfghj"
HIGH_CTRL_BLACK_KEYS = "yiadg"

def is_black_key(note_name):
    return "#" in note_name

def midi_note_to_name(note):
    octave = (note // 12) - 1
    name = NOTE_NAMES[note % 12]
    return f"{name}{octave}"

def get_key_and_shift(midi_note):
    """
    Returns (key, shift, ctrl) for given midi_note number.
    ctrl is boolean indicating if Ctrl modifier is needed.
    """
    # Low range: MIDI 21-35 (A0 to B2) => Ctrl keys low
    if 21 <= midi_note <= 35:
        idx = midi_note - 21  # 0-based index
        key = LOW_CTRL_KEYS[idx]
        shift = 1 if key in LOW_CTRL_BLACK_KEYS else 0
        return (key, shift, True)

    # Middle range: MIDI 36-96 (61 keys) => normal keys (use Roblox piano mapping)
    # Mapping adapted from your previous KEYBOARD_MAPPING, but numeric MIDI keys used here:
    midi_to_key = {
        36: ("1", 0), 37: ("1", 1), 38: ("2", 0), 39: ("2", 1), 40: ("3", 0),
        41: ("4", 0), 42: ("4", 1), 43: ("5", 0), 44: ("5", 1), 45: ("6", 0),
        46: ("6", 1), 47: ("7", 0), 48: ("8", 0), 49: ("8", 1), 50: ("9", 0),
        51: ("9", 1), 52: ("0", 0), 53: ("q", 0), 54: ("q", 1), 55: ("w", 0),
        56: ("w", 1), 57: ("e", 0), 58: ("e", 1), 59: ("r", 0), 60: ("t", 0),
        61: ("t", 1), 62: ("y", 0), 63: ("y", 1), 64: ("u", 0), 65: ("i", 0),
        66: ("i", 1), 67: ("o", 0), 68: ("o", 1), 69: ("p", 0), 70: ("p", 1),
        71: ("a", 0), 72: ("s", 0), 73: ("s", 1), 74: ("d", 0), 75: ("d", 1),
        76: ("f", 0), 77: ("g", 0), 78: ("g", 1), 79: ("h", 0), 80: ("h", 1),
        81: ("j", 0), 82: ("j", 1), 83: ("k", 0), 84: ("l", 0), 85: ("l", 1),
        86: ("z", 0), 87: ("z", 1), 88: ("x", 0), 89: ("c", 0), 90: ("c", 1),
        91: ("v", 0), 92: ("v", 1), 93: ("b", 0), 94: ("b", 1), 95: ("n", 0),
        96: ("m", 0),
    }
    if midi_note in midi_to_key:
        return (*midi_to_key[midi_note], False)

    # High range: MIDI 97-108 (C7 to C8) => Ctrl keys high
    if 97 <= midi_note <= 108:
        idx = midi_note - 97  # 0-based
        key = HIGH_CTRL_KEYS[idx]
        shift = 1 if key in HIGH_CTRL_BLACK_KEYS else 0
        return (key, shift, True)

    # If out of range, return None (ignore)
    return (None, None, None)

def tick_to_seconds(ticks, tempo, ticks_per_beat):
    # tempo in microseconds per beat
    return (ticks * tempo) / (ticks_per_beat * 1_000_000)

def convert_midi_to_csv(midi_path, csv_path):
    mid = mido.MidiFile(midi_path)
    ticks_per_beat = mid.ticks_per_beat
    default_tempo = 500000  # 120 BPM default

    tempo_changes = [(0, default_tempo)]
    all_events = []

    for track in mid.tracks:
        abs_tick = 0
        for msg in track:
            abs_tick += msg.time
            if msg.type == 'set_tempo':
                tempo_changes.append((abs_tick, msg.tempo))
            elif msg.type == 'note_on' and msg.velocity > 0:
                all_events.append((abs_tick, msg.note, msg.velocity))

    tempo_changes.sort(key=lambda x: x[0])
    all_events.sort(key=lambda x: x[0])

    output = []
    tempo_idx = 0
    current_tempo = tempo_changes[0][1]
    last_tick = 0
    current_time = 0.0

    for abs_tick, note, velocity in all_events:
        while (tempo_idx + 1 < len(tempo_changes)) and (abs_tick >= tempo_changes[tempo_idx + 1][0]):
            prev_tick, prev_tempo = tempo_changes[tempo_idx]
            next_tick, next_tempo = tempo_changes[tempo_idx + 1]
            delta_ticks = next_tick - last_tick
            current_time += tick_to_seconds(delta_ticks, current_tempo, ticks_per_beat)
            tempo_idx += 1
            current_tempo = next_tempo
            last_tick = next_tick

        delta_ticks = abs_tick - last_tick
        current_time += tick_to_seconds(delta_ticks, current_tempo, ticks_per_beat)
        last_tick = abs_tick

        key, shift, ctrl = get_key_and_shift(note)
        if key is not None:
            # Compose key field: prepend "Ctrl+" if ctrl is True
            csv_key = f"Ctrl+{key}" if ctrl else key
            output.append({'time_ms': round(current_time * 1000), 'key': csv_key, 'shift': shift})

    # Write CSV
    with open(csv_path, 'w', newline='') as f:
        # Write tempo change comments for reference (optional)
        f.write(f"# initial_tempo={round(60000000 / tempo_changes[0][1])} bpm\n")
        for t_tick, t_tempo in tempo_changes:
            bpm = round(60000000 / t_tempo)
            f.write(f"# tempo_change_tick={t_tick} bpm={bpm}\n")
        writer = csv.DictWriter(f, fieldnames=['time_ms', 'key', 'shift'])
        writer.writeheader()
        writer.writerows(output)

    print(f"Successfully converted {midi_path} to {csv_path}")

if __name__ == "__main__":
    import sys
    if len(sys.argv) != 3:
        print("Usage: python midi_to_csv.py input.mid output.csv")
    else:
        convert_midi_to_csv(sys.argv[1], sys.argv[2])
