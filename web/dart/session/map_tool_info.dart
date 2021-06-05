String getToolInfo(String tool, bool dm) {
  switch (tool) {
    case 'draw':
      return 'Hold <i>Left Click</i> and move across the map to draw.';

    case 'erase':
      return 'Hold <i>Left Click</i> and move through strokes to remove them.' +
          (dm
              ? '<br><br>Hold <i>Shift</i> to affect strokes by any player.'
              : '');

    case 'text':
      return 'Click anywhere on the map to create a new text object.';

    case 'pin':
      return '''Click anywhere on the map to visualize where the players
      are located.<br><br>
      Press <i>Delete</i> or <i>Backspace</i> to hide the pin.''';

    case 'change':
      return 'Upload a new image for this map.';

    case 'clear':
      return 'Removes every text and drawn line from this map.';
  }
  return null;
}
