import std/[times, os, terminal, strformat]

type Logger* = ref object
    filename: string
    dirname: string
    path: string

type Level* = enum
    INFO
    DEBUG
    WARN
    ERROR

proc getColor(level: Level): ForegroundColor =
    case level:
        of INFO:
            fgGreen
        of DEBUG:
            fgBlue
        of WARN:
            fgYellow
        of ERROR:
            fgRed

proc log*(self: Logger, level: Level, message: string, ignoreConsole: bool = false) =
    let currentDate = now().utc().format("dd-MM-yyyy");
    if self.dirname != currentDate:
        self.dirname = currentDate;

        if not dirExists(self.path & "/" & self.dirname):
            createDir(self.path & "/" & self.dirname);

    let date = $now().utc();
    let filepath = self.path & "/" & self.dirname & "/" & self.filename;

    if not ignoreConsole:
        stdout.styledWriteLine("[", fgMagenta, filepath, resetStyle, "][", getColor(level), $level, resetStyle, "][", fgGreen, date, resetStyle, "]: ", message);

    let message = fmt"[{$level}][{$date}]: {message}";

    if not fileExists(filepath):
        writeFile(filepath, message & '\n');
    else:
        let file = open(filepath, fmAppend);
        defer:
            file.close();
        file.writeLine(message);

proc newLogger*(path: string, filename: string): Logger =
    Logger(
        path: path,
        filename: filename
    )