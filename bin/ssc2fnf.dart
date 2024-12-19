import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart';

class FnfSong {
  String song = "a";
  List<double> sectionLengths = [];
  String player1 = "bf";
  String player2 = "dad";
  String gfVersion = "gf";
  List<(double, List<List<String>>)> events = [];
  List<FnfSection> notes = [];
  String? player3;
  double bpm = 120.0;
  double speed = 2.0;
  bool validScore = true;
  bool needsVoices = false;

  static FnfSong fromMap(Map data) {
    return FnfSong()
      ..song = data["song"]
      ..sectionLengths = data["sectionLengths"]
      ..player1 = data["player1"]
      ..player2 = data["player2"]
      ..gfVersion = data["gfVersion"]
      ..events = data["events"].map((e) => (e[0], e[1])).toList()
      ..notes = data["notes"].map((e) => FnfSection.fromMap(e)).toList()
      ..bpm = data["bpm"]
      ..speed = data["speed"]
      ..validScore = data["validScore"]
      ..needsVoices = data["needsVoices"];
  }

  Map<String, dynamic> toMap() {
    return {
      "song": song,
      "sectionLengths": sectionLengths,
      "player1": player1,
      "player2": player2,
      "gfVersion": gfVersion,
      "events": events.map((e) => [e.$1, e.$2]).toList(),
      "notes": notes.map((e) => e.toMap()).toList(),
      "bpm": bpm,
      "speed": speed,
      "validScore": validScore,
      "needsVoices": needsVoices,
    };
  }
}

class FnfSection {
  double sectionBeats = 4;
  List<List<dynamic>> sectionNotes = [];
  int lengthInSteps = 16; // unused
  int typeOfSection = 0; // ??? idk what it does
  bool gfSection = false; // makes GF do the animations instead
  bool mustHitSection = true; // flips sides
  double bpm = 0;
  bool changeBPM = false;
  bool altAnim = false;

  static FnfSection fromMap(Map data) {
    return FnfSection()
      ..sectionBeats = data["sectionBeats"]
      ..sectionNotes = data["sectionNotes"]
      ..lengthInSteps = data["lengthInSteps"]
      ..typeOfSection = data["typeOfSection"]
      ..gfSection = data["gfSection"]
      ..mustHitSection = data["mustHitSection"]
      ..bpm = data["bpm"]
      ..changeBPM = data["changeBPM"]
      ..altAnim = data["altAnim"];
  }

  Map<String, dynamic> toMap() {
    return {
      "sectionBeats": sectionBeats,
      "sectionNotes": sectionNotes,
      "lengthInSteps": lengthInSteps,
      "typeOfSection": typeOfSection,
      "gfSection": gfSection,
      "mustHitSection": mustHitSection,
      "bpm": bpm,
      "changeBPM": changeBPM,
      "altAnim": altAnim,
    };
  }
}

void main(List<String> arguments) {
  final parser = ArgParser()
    ..addOption('output', abbr: 'o', mandatory: false, defaultsTo: "output");

  ArgResults argResults = parser.parse(arguments);
  final paths = argResults.rest;

  if (paths.isEmpty) {
    print('Missing path for sm file!');
    exit(1);
  }

  var inputPath = paths[0];
  var input = File(inputPath).readAsStringSync();

  var bpms = {0.0: 120.0};
  // time: (new_speed, time, timeIsInSeconds)
  Map<double, (double, double, bool)> speeds = {};
  var offset = 0.0;

  var chartBpms = {};
  // time: (new_speed, time, timeIsInSeconds)
  Map<double, (double, double, bool)> chartSpeeds = {};
  double chartOffset = offset;

  String chartName = "";
  String credit = "";
  String description = "";
  String stepsType = "";
  String difficulty = "";

  var readingNoteData = false;

  Map<String, FnfSong> charts = {};

  for (var command in (input.split(';')
        ..removeWhere(
          (text) {
            return text.trim().isEmpty;
          },
        ))
      .map(
    (text) {
      return text.substring(text.indexOf('#') + 1);
    },
  )) {
    var splitPos = command.indexOf(RegExp(r"(?<!\\)(?:\\\\)*:"));
    var name = command.substring(0, splitPos).trim().toUpperCase();
    var value = command.substring(splitPos + 1).trim();
    switch (name) {
      case ('BPMS'):
        var pairs = value.split(',').map((pair) {
          var splitIndex = pair.indexOf('=');
          return MapEntry(double.parse(pair.substring(0, splitIndex)),
              double.parse(pair.substring(splitIndex + 1)));
        });
        bpms = Map.fromEntries(pairs);
        break;
      case ('NOTEDATA'):
        readingNoteData = true;
        chartOffset = offset;
        chartBpms = {};
        chartSpeeds = {};
        break;
      case ('OFFSET'):
        if (readingNoteData) {
          chartOffset = double.parse(value);
        } else {
          offset = double.parse(value);
        }
        break;
      // case ('STOPS'):
      //   if (!value.contains("=")) {
      //     stops = {};
      //     break;
      //   }
      //   var pairs = value.split(',').map((pair) {
      //     var splitIndex = pair.indexOf('=');
      //     return MapEntry(double.parse(pair.substring(0, splitIndex)),
      //         double.parse(pair.substring(splitIndex + 1)));
      //   });
      //   stops = Map.fromEntries(pairs);
      //   break;
      case ('SPEEDS'):
        if (!value.contains(",")) {
          if (readingNoteData) {
            chartSpeeds = {};
          } else {
            speeds = {};
          }
          break;
        }
        var pairs = value.split(',').map((eventRaw) {
          var values = eventRaw.split('=');
          return MapEntry(
            double.parse(values[0]),
            (
              double.parse(values[1]),
              double.parse(values[2]),
              int.parse(values[3]) == 1
            ),
          );
        });
        if (readingNoteData) {
          chartSpeeds = Map.fromEntries(pairs);
        } else {
          speeds = Map.fromEntries(pairs);
        }
        break;
      case ('DIFFICULTY'):
        switch (value) {
          case "beginner":
            value = "baby";
            break;
          case "easy":
            value = "easy";
            break;
          case "medium":
            // Normal difficulty has no name
            break;
          case "hard":
            value = "hard";
            break;
          case "challenge":
            value = "erect";
            break;
          case "edit":
            value = "edit${credit.isNotEmpty ? '-' : ''}$credit";
          default:
            if (description.isEmpty) {
              value = chartName;
            } else {
              value = description;
            }
        }
        break;
      case ('NOTES'):
        var noteData = value.toUpperCase().split(',').map((text) {
          return (text
              .trim()
              .replaceAll(RegExp(r'[^0-9MLFAKNH/\n]'), ',')
              .split('\n')
            ..removeWhere(
                (text) => text.trim().startsWith("//") || text.trim().isEmpty));
        }).toList();

        // if (mode != 'dance-couple') continue;

        String? difficultyName;

        Set<double> processedBpms = {};
        Set<double> processedSpeeds = {};

        var currentBpm = 120.0;
        var timingOffsetBeats = 0.0;
        var timingOffsetSeconds = 0.0;

        var currentBeatsInsideMeasureProcessed = 0.0;
        // Beats already accounted for (aka. the beats from the measures before)
        var beatsProcessed = 0.0;

        // key is the lane, value is (section, index inside section)
        Map<int, (int, int)> lastHoldHeadPosition = {};

        var song = FnfSong();
        for (var measure = 0; measure < noteData.length; measure++) {
          var measureData = noteData[measure];
          var divisions = measureData.length;
          var currentSection = FnfSection();
          for (var i = 0; i < divisions; i++) {
            var currentBeatInMeasure = (4.0 / divisions) * i;
            var currentBeat = beatsProcessed + currentBeatInMeasure;

            var unprocessedBpms = bpms.keys
                .skipWhile(
                  (beat) => processedBpms.contains(beat),
                )
                .toList()
              ..sort();
            var unprocessedSpeeds = speeds.keys
                .skipWhile(
                  (beat) => processedSpeeds.contains(beat),
                )
                .toList()
              ..sort();

            double beatToSeconds(beat) {
              return (beat - timingOffsetBeats) * 60 / currentBpm +
                  timingOffsetSeconds -
                  offset;
            }

            void changeBPM(beat, newBpm) {
              if (beat == 0) {
                song.bpm = newBpm;
              }

              timingOffsetSeconds = beatToSeconds(beat);
              timingOffsetBeats = beat;
              currentBpm = newBpm;

              currentSection.changeBPM = beat != 0;
              currentSection.bpm = newBpm;
              if (beat != beatsProcessed) {
                currentSection.sectionBeats = beat - beatsProcessed;
                song.notes.add(currentSection);
                currentSection = FnfSection();
                currentSection.sectionBeats = 4.0 - beat - beatsProcessed;
              }
              processedBpms.add(beat);
            }

            void processSpeed(beat, newSpeed, length, isLengthInSeconds) {
              var startTime = beatToSeconds(beat);
              var endTime = length;
              if (!isLengthInSeconds) {
                // Horrible garbage, but im tired
                var tempTimingOffsetBeats = timingOffsetBeats;
                var tempCurrentBpm = currentBpm;
                var tempTimingOffsetSeconds = timingOffsetSeconds;
                var tempUnprocessedBpms = unprocessedBpms;
                while (tempUnprocessedBpms.isNotEmpty &&
                    beat > tempUnprocessedBpms.first) {
                  var beat = tempUnprocessedBpms.removeAt(0);
                  tempTimingOffsetSeconds =
                      (beat - tempTimingOffsetBeats) * 60 / tempCurrentBpm +
                          tempTimingOffsetSeconds -
                          chartOffset;
                  tempTimingOffsetBeats = beat;
                  tempCurrentBpm = bpms[beat]!;
                }
                endTime = ((beat + length) - tempTimingOffsetBeats) *
                        60 /
                        tempCurrentBpm +
                    tempTimingOffsetSeconds -
                    chartOffset;
              }
              processedSpeeds.add(beat);
              assert(endTime >= startTime);
              var endSpeed = speeds[beat]!.$1.clamp(-50, 50);
              // if (endSpeed == 0) {
              //   endSpeed = double.minPositive;
              // }
              song.events.add((
                startTime * 1000,
                [
                  [
                    "Change Scroll Speed",
                    endSpeed.toString(),
                    (endTime - startTime).toString()
                  ]
                ],
              ));
            }

            while (unprocessedBpms.isNotEmpty && unprocessedSpeeds.isNotEmpty) {
              if (unprocessedBpms.first <= currentBeat &&
                  unprocessedSpeeds.first > currentBeat) {
                var beat = unprocessedBpms.removeAt(0);
                changeBPM(beat, bpms[beat]);
              } else if (unprocessedBpms.first > currentBeat &&
                  unprocessedSpeeds.first <= currentBeat) {
                var beat = unprocessedSpeeds.removeAt(0);
                processSpeed(
                  beat,
                  speeds[beat]!.$1,
                  speeds[beat]!.$2,
                  speeds[beat]!.$3,
                );
              } else if (unprocessedBpms.first <= currentBeat &&
                  unprocessedSpeeds.first <= currentBeat) {
                if (unprocessedBpms.first <= unprocessedSpeeds.first) {
                  var beat = unprocessedBpms.removeAt(0);
                  changeBPM(beat, bpms[beat]);
                } else {
                  var beat = unprocessedSpeeds.removeAt(0);
                  processSpeed(
                    beat,
                    speeds[beat]!.$1,
                    speeds[beat]!.$2,
                    speeds[beat]!.$3,
                  );
                }
              } else {
                break;
              }
            }

            while (unprocessedBpms.isNotEmpty) {
              if (unprocessedBpms.first <= currentBeat) {
                var beat = unprocessedBpms.removeAt(0);
                changeBPM(beat, bpms[beat]);
              } else {
                break;
              }
            }

            while (unprocessedSpeeds.isNotEmpty) {
              if (unprocessedSpeeds.first <= currentBeat) {
                var beat = unprocessedSpeeds.removeAt(0);
                processSpeed(
                  beat,
                  speeds[beat]!.$1,
                  speeds[beat]!.$2,
                  speeds[beat]!.$3,
                );
              } else {
                break;
              }
            }

            // void addStop(beat, newBpm) {
            // }

            var currentSecond = beatToSeconds(currentBeat);

            var rowData = measureData[i];
            for (var lane = 0; lane < rowData.length; lane++) {
              switch (rowData.substring(lane, lane + 1)) {
                case '1':
                  currentSection.sectionNotes.add(
                    [currentSecond * 1000, lane, 0],
                  );
                  break;
                case 'M':
                  currentSection.sectionNotes.add(
                    [currentSecond * 1000, lane, 0, 'Hurt Note'],
                  );
                  break;
                case '2':
                case '4':
                  lastHoldHeadPosition[lane] =
                      (song.notes.length, currentSection.sectionNotes.length);
                  currentSection.sectionNotes.add(
                    [currentSecond * 1000, lane, 0],
                  );
                  break;
                case '3':
                  if (!lastHoldHeadPosition.containsKey(lane)) {
                    throw Exception(
                        "Hold tail without head at measure $measure from difficulty $difficulty");
                  }
                  var sectionIndex = lastHoldHeadPosition[lane]!.$1;
                  var noteInsideSectionIndex = lastHoldHeadPosition[lane]!.$2;
                  if (sectionIndex == song.notes.length) {
                    currentSection.sectionNotes[noteInsideSectionIndex][2] =
                        currentSecond * 1000 -
                            currentSection.sectionNotes[noteInsideSectionIndex]
                                [0];
                  } else {
                    song.notes[sectionIndex]
                            .sectionNotes[noteInsideSectionIndex][2] =
                        currentSecond * 1000 -
                            song.notes[sectionIndex]
                                .sectionNotes[noteInsideSectionIndex][0];
                  }
                  lastHoldHeadPosition.remove(lane);
                  break;
              }
            }
          }
          song.notes.add(currentSection);
          currentSection = FnfSection();
          beatsProcessed += 4.0;
        }
        charts[difficultyName ?? ""] = song;
        break;
    }
  }
  charts.forEach((difficulty, data) {
    Directory(argResults.option('output')!).createSync();
    var filename =
        "${argResults.option('output')!}/${basenameWithoutExtension(inputPath)}";
    if (difficulty.isNotEmpty) {
      filename += "-$difficulty";
    }
    filename += ".json";
    File(filename)
      ..createSync(recursive: true)
      ..writeAsStringSync(jsonEncode({"song": data.toMap()}));
  });
}
