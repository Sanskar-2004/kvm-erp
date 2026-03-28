import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/notice_model.dart';

final noticesListProvider = Provider<List<NoticeModel>>((ref) {
  return [
    NoticeModel(
      id: '1',
      title: 'Annual Day Celebration',
      description:
          'The annual day celebration will be held on 15th April 2026. All students are requested to participate in cultural activities. Parents are invited.',
      postedBy: 'Principal',
      targetAudience: 'all',
      postedAt: DateTime(2026, 3, 20),
      isImportant: true,
    ),
    NoticeModel(
      id: '2',
      title: 'Mid-Term Exam Schedule',
      description:
          'Mid-term examinations will commence from 1st April 2026. The detailed schedule has been uploaded. Students must carry their admit cards.',
      postedBy: 'Exam Controller',
      targetAudience: 'students',
      postedAt: DateTime(2026, 3, 18),
      isImportant: true,
    ),
    NoticeModel(
      id: '3',
      title: 'Parent-Teacher Meeting',
      description:
          'PTM for all classes will be held on 28th March 2026 from 10 AM to 1 PM. Parents are requested to attend.',
      postedBy: 'Vice Principal',
      targetAudience: 'parents',
      postedAt: DateTime(2026, 3, 15),
    ),
  ];
});
