final printableChars =
    " !\"#\$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~".codeUnits;

final characters = [
  '\u{FFFD}', // 0x00 (Replacement Character)
  '\u{FFFD}', // 0x01 (Replacement Character)
  '\u{FFFD}', // 0x02 (Replacement Character)
  '\u{FFFD}', // 0x03 (Replacement Character)
  '\u{FFFD}', // 0x04 (Replacement Character)
  '\u{FFFD}', // 0x05 (Replacement Character)
  '\u{FFFD}', // 0x06 (Replacement Character)
  '\u{FFFD}', // 0x07 (Replacement Character)
  '\u{FFFD}', // 0x08 (Replacement Character)
  '\u{FFFD}', // 0x09 (Replacement Character)
  '\u{FFFD}', // 0x0A (Replacement Character)
  '\u{FFFD}', // 0x0B (Replacement Character)
  '\u{FFFD}', // 0x0C (Replacement Character)
  '\u{FFFD}', // 0x0D (Replacement Character)
  '\u{FFFD}', // 0x0E (Replacement Character)
  '\u{FFFD}', // 0x0F (Replacement Character)
  '\u{FFFD}', // 0x10 (Replacement Character)
  '\u{FFFD}', // 0x11 (Replacement Character)
  '\u{FFFD}', // 0x12 (Replacement Character)
  '\u{FFFD}', // 0x13 (Replacement Character)
  '\u{FFFD}', // 0x14 (Replacement Character)
  '\u{FFFD}', // 0x15 (Replacement Character)
  '\u{FFFD}', // 0x16 (Replacement Character)
  '\u{FFFD}', // 0x17 (Replacement Character)
  '\u{FFFD}', // 0x18 (Replacement Character)
  '\u{FFFD}', // 0x19 (Replacement Character)
  '\u{FFFD}', // 0x1A (Replacement Character)
  '\u{FFFD}', // 0x1B (Replacement Character)
  '\u{FFFD}', // 0x1C (Replacement Character)
  '\u{FFFD}', // 0x1D (Replacement Character)
  '\u{FFFD}', // 0x1E (Replacement Character)
  '\u{FFFD}', // 0x1F (Replacement Character)
  ' ',        // 0x20 (Space)
  '!',        // 0x21
  '"',        // 0x22
  '#',        // 0x23
  '\$',       // 0x24
  '%',        // 0x25
  '&',        // 0x26
  '\'',       // 0x27
  '(',        // 0x28
  ')',        // 0x29
  '*',        // 0x2A
  '+',        // 0x2B
  ',',        // 0x2C
  '-',        // 0x2D
  '.',        // 0x2E
  '/',        // 0x2F
  '0',        // 0x30
  '1',        // 0x31
  '2',        // 0x32
  '3',        // 0x33
  '4',        // 0x34
  '5',        // 0x35
  '6',        // 0x36
  '7',        // 0x37
  '8',        // 0x38
  '9',        // 0x39
  ':',        // 0x3A
  ';',        // 0x3B
  '<',        // 0x3C
  '=',        // 0x3D
  '>',        // 0x3E
  '?',        // 0x3F
  '@',        // 0x40
  'A',        // 0x41
  'B',        // 0x42
  'C',        // 0x43
  'D',        // 0x44
  'E',        // 0x45
  'F',        // 0x46
  'G',        // 0x47
  'H',        // 0x48
  'I',        // 0x49
  'J',        // 0x4A
  'K',        // 0x4B
  'L',        // 0x4C
  'M',        // 0x4D
  'N',        // 0x4E
  'O',        // 0x4F
  'P',        // 0x50
  'Q',        // 0x51
  'R',        // 0x52
  'S',        // 0x53
  'T',        // 0x54
  'U',        // 0x55
  'V',        // 0x56
  'W',        // 0x57
  'X',        // 0x58
  'Y',        // 0x59
  'Z',        // 0x5A
  '[',        // 0x5B
  '\\',       // 0x5C
  ']',        // 0x5D
  '^',        // 0x5E
  '_',        // 0x5F
  '`',        // 0x60
  'a',        // 0x61
  'b',        // 0x62
  'c',        // 0x63
  'd',        // 0x64
  'e',        // 0x65
  'f',        // 0x66
  'g',        // 0x67
  'h',        // 0x68
  'i',        // 0x69
  'j',        // 0x6A
  'k',        // 0x6B
  'l',        // 0x6C
  'm',        // 0x6D
  'n',        // 0x6E
  'o',        // 0x6F
  'p',        // 0x70
  'q',        // 0x71
  'r',        // 0x72
  's',        // 0x73
  't',        // 0x74
  'u',        // 0x75
  'v',        // 0x76
  'w',        // 0x77
  'x',        // 0x78
  'y',        // 0x79
  'z',        // 0x7A
  '{',        // 0x7B
  '|',        // 0x7C
  '}',        // 0x7D
  '~',        // 0x7E
  '\u{FFFD}', // 0x7F (Replacement Character)
  '\u{FFFD}', // 0x80 (Replacement Character)
  '\u{FFFD}', // 0x81 (Replacement Character)
  '\u{FFFD}', // 0x82 (Replacement Character)
  '\u{FFFD}', // 0x83 (Replacement Character)
  '\u{FFFD}', // 0x84 (Replacement Character)
  '\u{FFFD}', // 0x85 (Replacement Character)
  '\u{FFFD}', // 0x86 (Replacement Character)
  '\u{FFFD}', // 0x87 (Replacement Character)
  '\u{FFFD}', // 0x88 (Replacement Character)
  '\u{FFFD}', // 0x89 (Replacement Character)
  '\u{FFFD}', // 0x8A (Replacement Character)
  '\u{FFFD}', // 0x8B (Replacement Character)
  '\u{FFFD}', // 0x8C (Replacement Character)
  '\u{FFFD}', // 0x8D (Replacement Character)
  '\u{FFFD}', // 0x8E (Replacement Character)
  '\u{FFFD}', // 0x8F (Replacement Character)
  '\u{FFFD}', // 0x90 (Replacement Character)
  '\u{FFFD}', // 0x91 (Replacement Character)
  '\u{FFFD}', // 0x92 (Replacement Character)
  '\u{FFFD}', // 0x93 (Replacement Character)
  '\u{FFFD}', // 0x94 (Replacement Character)
  '\u{FFFD}', // 0x95 (Replacement Character)
  '\u{FFFD}', // 0x96 (Replacement Character)
  '\u{FFFD}', // 0x97 (Replacement Character)
  '\u{FFFD}', // 0x98 (Replacement Character)
  '\u{FFFD}', // 0x99 (Replacement Character)
  '\u{FFFD}', // 0x9A (Replacement Character)
  '\u{FFFD}', // 0x9B (Replacement Character)
  '\u{FFFD}', // 0x9C (Replacement Character)
  '\u{FFFD}', // 0x9D (Replacement Character)
  '\u{FFFD}', // 0x9E (Replacement Character)
  '\u{FFFD}', // 0x9F (Replacement Character)
  '\u{FFFD}', // 0xA0 (Replacement Character)
  '\u{FFFD}', // 0xA1 (Replacement Character)
  '\u{FFFD}', // 0xA2 (Replacement Character)
  '\u{FFFD}', // 0xA3 (Replacement Character)
  '\u{FFFD}', // 0xA4 (Replacement Character)
  '\u{FFFD}', // 0xA5 (Replacement Character)
  '\u{FFFD}', // 0xA6 (Replacement Character)
  '\u{FFFD}', // 0xA7 (Replacement Character)
  '\u{FFFD}', // 0xA8 (Replacement Character)
  '\u{FFFD}', // 0xA9 (Replacement Character)
  '\u{FFFD}', // 0xAA (Replacement Character)
  '\u{FFFD}', // 0xAB (Replacement Character)
  '\u{FFFD}', // 0xAC (Replacement Character)
  '\u{FFFD}', // 0xAD (Replacement Character)
  '\u{FFFD}', // 0xAE (Replacement Character)
  '\u{FFFD}', // 0xAF (Replacement Character)
  '\u{FFFD}', // 0xB0 (Replacement Character)
  '\u{FFFD}', // 0xB1 (Replacement Character)
  '\u{FFFD}', // 0xB2 (Replacement Character)
  '\u{FFFD}', // 0xB3 (Replacement Character)
  '\u{FFFD}', // 0xB4 (Replacement Character)
  '\u{FFFD}', // 0xB5 (Replacement Character)
  '\u{FFFD}', // 0xB6 (Replacement Character)
  '\u{FFFD}', // 0xB7 (Replacement Character)
  '\u{FFFD}', // 0xB8 (Replacement Character)
  '\u{FFFD}', // 0xB9 (Replacement Character)
  '\u{FFFD}', // 0xBA (Replacement Character)
  '\u{FFFD}', // 0xBB (Replacement Character)
  '\u{FFFD}', // 0xBC (Replacement Character)
  '\u{FFFD}', // 0xBD (Replacement Character)
  '\u{FFFD}', // 0xBE (Replacement Character)
  '\u{FFFD}', // 0xBF (Replacement Character)
  '\u{FFFD}', // 0xC0 (Replacement Character)
  '\u{FFFD}', // 0xC1 (Replacement Character)
  '\u{FFFD}', // 0xC2 (Replacement Character)
  '\u{FFFD}', // 0xC3 (Replacement Character)
  '\u{FFFD}', // 0xC4 (Replacement Character)
  '\u{FFFD}', // 0xC5 (Replacement Character)
  '\u{FFFD}', // 0xC6 (Replacement Character)
  '\u{FFFD}', // 0xC7 (Replacement Character)
  '\u{FFFD}', // 0xC8 (Replacement Character)
  '\u{FFFD}', // 0xC9 (Replacement Character)
  '\u{FFFD}', // 0xCA (Replacement Character)
  '\u{FFFD}', // 0xCB (Replacement Character)
  '\u{FFFD}', // 0xCC (Replacement Character)
  '\u{FFFD}', // 0xCD (Replacement Character)
  '\u{FFFD}', // 0xCE (Replacement Character)
  '\u{FFFD}', // 0xCF (Replacement Character)
  '\u{FFFD}', // 0xD0 (Replacement Character)
  '\u{FFFD}', // 0xD1 (Replacement Character)
  '\u{FFFD}', // 0xD2 (Replacement Character)
  '\u{FFFD}', // 0xD3 (Replacement Character)
  '\u{FFFD}', // 0xD4 (Replacement Character)
  '\u{FFFD}', // 0xD5 (Replacement Character)
  '\u{FFFD}', // 0xD6 (Replacement Character)
  '\u{FFFD}', // 0xD7 (Replacement Character)
  '\u{FFFD}', // 0xD8 (Replacement Character)
  '\u{FFFD}', // 0xD9 (Replacement Character)
  '\u{FFFD}', // 0xDA (Replacement Character)
  '\u{FFFD}', // 0xDB (Replacement Character)
  '\u{FFFD}', // 0xDC (Replacement Character)
  '\u{FFFD}', // 0xDD (Replacement Character)
  '\u{FFFD}', // 0xDE (Replacement Character)
  '\u{FFFD}', // 0xDF (Replacement Character)
  '\u{FFFD}', // 0xE0 (Replacement Character)
  '\u{FFFD}', // 0xE1 (Replacement Character)
  '\u{FFFD}', // 0xE2 (Replacement Character)
  '\u{FFFD}', // 0xE3 (Replacement Character)
  '\u{FFFD}', // 0xE4 (Replacement Character)
  '\u{FFFD}', // 0xE5 (Replacement Character)
  '\u{FFFD}', // 0xE6 (Replacement Character)
  '\u{FFFD}', // 0xE7 (Replacement Character)
  '\u{FFFD}', // 0xE8 (Replacement Character)
  '\u{FFFD}', // 0xE9 (Replacement Character)
  '\u{FFFD}', // 0xEA (Replacement Character)
  '\u{FFFD}', // 0xEB (Replacement Character)
  '\u{FFFD}', // 0xEC (Replacement Character)
  '\u{FFFD}', // 0xED (Replacement Character)
  '\u{FFFD}', // 0xEE (Replacement Character)
  '\u{FFFD}', // 0xEF (Replacement Character)
  '\u{FFFD}', // 0xF0 (Replacement Character)
  '\u{FFFD}', // 0xF1 (Replacement Character)
  '\u{FFFD}', // 0xF2 (Replacement Character)
  '\u{FFFD}', // 0xF3 (Replacement Character)
  '\u{FFFD}', // 0xF4 (Replacement Character)
  '\u{FFFD}', // 0xF5 (Replacement Character)
  '\u{FFFD}', // 0xF6 (Replacement Character)
  '\u{FFFD}', // 0xF7 (Replacement Character)
  '\u{FFFD}', // 0xF8 (Replacement Character)
  '\u{FFFD}', // 0xF9 (Replacement Character)
  '\u{FFFD}', // 0xFA (Replacement Character)
  '\u{FFFD}', // 0xFB (Replacement Character)
  '\u{FFFD}', // 0xFC (Replacement Character)
  '\u{FFFD}', // 0xFD (Replacement Character)
  '\u{FFFD}', // 0xFE (Replacement Character)
  '\u{FFFD}', // 0xFF (Replacement Character)
];