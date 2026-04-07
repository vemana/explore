/// Parameters that control painting the Simstate simulation.
class SimVisualParams {
  SimVisualParams(this.levels);

  final int levels;

  // Divide the screen size using scaled parameters.
  // ratioGateRadiusToHeight + ratioLevelSeparationToHeight * levels
  // + ratioBucketHeightToScreenHeight + ratioBucketBaseToScreenHeight = 0.99
  final double surroundSpace = 5;
  final double ratioBucketHeightToScreenHeight = 0.35;
  final double ratioSpaceBetweenBucketsToBucketWidth = 0.5;
  final double ratioBucketBaseToScreenHeight = 0.05; // height of bucket
  late final double ratioGateRadiusToHeight = 0.10 / (levels);
  late final double ratioPointRadiusToHeight = 0.03 / levels;

  // Yes, this is a single ratioGateRadiusToHeight (not multiplied by levels) since we need
  // to remove the diameter of one gate (the bottom most and top most) to obtain the height
  // available for level separations.
  late final double ratioLevelSeparationToHeight = (0.59 - ratioGateRadiusToHeight) / (levels);
}
