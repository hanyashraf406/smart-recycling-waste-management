import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/app_colors.dart';
import '../../services/firebase_service.dart';

class ReviewDialog extends StatefulWidget {
  final String reviewId;
  final int pointsEarned;

  const ReviewDialog({
    super.key,
    required this.reviewId,
    required this.pointsEarned,
  });

  @override
  State<ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<ReviewDialog>
    with SingleTickerProviderStateMixin {
  double _rating = 0.0;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;
  late AnimationController _animController;
  late Animation<double> _starAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _starAnimation = Tween<double>(begin: 0, end: 5).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
    _animController.addListener(() {
      if (mounted) {
        setState(() {
          _rating = _starAnimation.value;
        });
      }
    });
    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) _animController.reverse();
        });
      } else if (status == AnimationStatus.dismissed) {
        if (mounted) {
          setState(() {
            _rating = 0.0;
          });
        }
      }
    });
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _animController.forward();
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _skipReview() async {
    try {
      await FirebaseFirestore.instance
          .collection('reviews')
          .doc(widget.reviewId)
          .update({
        'status': 'skipped',
        'skippedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {}
    if (mounted) {
      Navigator.pop(context, false);
    }
  }

  Future<void> _submitReview() async {
    if (_rating == 0.0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a rating'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      await FirebaseService.submitReview(
        reviewId: widget.reviewId,
        rating: _rating,
        comment: _commentController.text.trim(),
      );
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting review: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.5, end: 1.0),
                duration: const Duration(milliseconds: 600),
                builder: (context, value, child) {
                  return Transform.scale(scale: value, child: child);
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.celebration,
                    color: AppColors.primary,
                    size: 40,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Congratulations!',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'You earned ${widget.pointsEarned} points!',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              Text(
                'How was your experience?',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final starValue = index + 1.0;
                  final isFilled = _rating >= starValue;
                  return GestureDetector(
                    onTap: () {
                      _animController.stop();
                      setState(() => _rating = starValue);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          isFilled ? Icons.star : Icons.star_border,
                          key: ValueKey(isFilled),
                          size: 32,
                          color: isFilled ? Colors.amber : Colors.grey[400],
                        ),
                      ),
                    ),
                  );
                }),
              ),
              if (_rating > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '${_rating.toStringAsFixed(0)} / 5',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ),
              const SizedBox(height: 12),
              SizedBox(
                height: 60,
                child: TextField(
                  controller: _commentController,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Leave a comment (optional)',
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.primary, width: 2),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _skipReview,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[600],
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    child: const Text('Skip', style: TextStyle(fontSize: 14)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitReview,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                        : const Text('Submit', style: TextStyle(fontSize: 14)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}