import 'package:common_ui_widgets/api.dart';
import 'package:flutter/material.dart';
import 'package:inject_annotation/inject_annotation.dart';

import '../state/help.dart';

@assistedFactory
abstract class HelpViewFactory {
  HelpView create({required HelpState helpState});
}

@assistedInject
class HelpView implements HasWidget {
  HelpView({@assisted required this.helpState});

  final HelpState helpState;

  @override
  Widget widget() {
    return Builder(
        builder: (context) => Text(
              "What is this? "
              "This is a GaltonBoard simulation. Each point takes a path through the gates to "
              "reach a bucket. Each gate sends a point left or right. A gate can be "
              "un-biased (sending a point left or right equally) or it can be biased "
              "(e.g. 70% points go left and 30% go right)."
              "\n\n"
              "Use the control panel to vary simulation parameters such as the number of levels, "
              "simulation speed, gate's bias & number of points to simulate."
              "\n\n"
              "Why is the outcome shaped like a Normal distribution (bell curve)? "
              "The Central Limit Theorem tells us that the sum of independent identical "
              "random variables converges to a Normal distribution. Informally, a large "
              "number of small-in-scope but similar choices add up to a bell curve."
              "\n\n"
              "Why is it useful? "
              "Think of each point as a person. Think of each gate as a decision a person "
              "makes in their life. Going right is a good decision while going left is a "
              "bad decision. Over a lifetime, different people end up in different buckets "
              "despite identical decision making (i.e 50% Right & 50% Left). "
              "However, people making 70% Right decisions as a whole tend to end up better "
              "off than those who make 50% Right decisions. "
              "Notably, many who make 50% Right decisions will still be better off than those "
              "who make 70% Right decisions. So, there's an element of luck which is "
              "uncontrolled. But, there's still plenty of control as well.",
              style: Theme.of(context).textTheme.displaySmall!.copyWith(
                    color: Colors.greenAccent,
                    fontWeight: FontWeight.normal,
                  ),
            ));
  }
}
