import 'package:flutter/material.dart';

class Editable extends StatefulWidget {
  const Editable({super.key, this.text = "", this.width, this.onSubmitted});

  final double? width;
  final String text;
  final ValueChanged<String>? onSubmitted;

  @override
  State<Editable> createState() => _EditableState();
}

class _EditableState extends State<Editable> {
  bool isEditing = false;
  String text = "";

  @override
  void initState() {
    super.initState();
    text = widget.text;
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      child: Container(
          alignment: Alignment.centerLeft,
          width: widget.width,
          padding: const EdgeInsets.only(left: 6, right: 6),
          child: isEditing
              ? TextFormField(
                  initialValue: text,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                      signed: true, decimal: true),
                  onFieldSubmitted: (value) {
                    setState(() {
                      text = double.tryParse(value) != null ? value : text;
                      isEditing = false;
                      widget.onSubmitted?.call(value);
                    });
                  },
                  onTapOutside: (value) {
                    setState(() {
                      isEditing = false;
                    });
                  },
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(text))),
      onTap: () {
        setState(() {
          isEditing = true;
        });
      },
    );
  }
}
