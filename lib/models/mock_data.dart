import '../models/album.dart';
import '../models/photo.dart';

List<Album> getMockAlbums() {
  return [
    Album(
      id: '1',
      title: '京都秋色',
      destination: '日本・京都',
      coverUrl: 'https://picsum.photos/seed/kyoto1/800/600',
      date: DateTime(2024, 11, 5),
      photos: List.generate(
        12,
        (i) => Photo(
          id: '1_$i',
          url: 'https://picsum.photos/seed/kyoto${i + 1}/1200/900',
          thumbnailUrl: 'https://picsum.photos/seed/kyoto${i + 1}/400/300',
          title: '京都第${i + 1}天',
          location: ['岚山', '伏见稻荷', '金阁寺', '清水寺', '祗园'][i % 5],
          takenAt: DateTime(2024, 11, 5 + i ~/ 3),
        ),
      ),
    ),
    Album(
      id: '2',
      title: '巴黎初夏',
      destination: '法国・巴黎',
      coverUrl: 'https://picsum.photos/seed/paris1/800/600',
      date: DateTime(2024, 6, 12),
      photos: List.generate(
        9,
        (i) => Photo(
          id: '2_$i',
          url: 'https://picsum.photos/seed/paris${i + 1}/1200/900',
          thumbnailUrl: 'https://picsum.photos/seed/paris${i + 1}/400/300',
          title: '巴黎第${i + 1}天',
          location: ['埃菲尔铁塔', '卢浮宫', '凡尔赛', '香榭丽舍', '蒙马特'][i % 5],
          takenAt: DateTime(2024, 6, 12 + i ~/ 3),
        ),
      ),
    ),
    Album(
      id: '3',
      title: '普罗旺斯薰衣草',
      destination: '法国・普罗旺斯',
      coverUrl: 'https://picsum.photos/seed/provence1/800/600',
      date: DateTime(2024, 7, 3),
      photos: List.generate(
        8,
        (i) => Photo(
          id: '3_$i',
          url: 'https://picsum.photos/seed/provence${i + 1}/1200/900',
          thumbnailUrl: 'https://picsum.photos/seed/provence${i + 1}/400/300',
          title: '薰衣草田第${i + 1}张',
          location: '瓦朗索勒',
          takenAt: DateTime(2024, 7, 3 + i ~/ 2),
        ),
      ),
    ),
    Album(
      id: '4',
      title: '新疆大漠星空',
      destination: '中国・新疆',
      coverUrl: 'https://picsum.photos/seed/xinjiang1/800/600',
      date: DateTime(2024, 8, 20),
      photos: List.generate(
        15,
        (i) => Photo(
          id: '4_$i',
          url: 'https://picsum.photos/seed/xinjiang${i + 1}/1200/900',
          thumbnailUrl: 'https://picsum.photos/seed/xinjiang${i + 1}/400/300',
          title: '新疆第${i + 1}天',
          location: ['喀纳斯', '禾木', '赛里木湖', '独山子大峡谷'][i % 4],
          takenAt: DateTime(2024, 8, 20 + i ~/ 3),
        ),
      ),
    ),
    Album(
      id: '5',
      title: '云南古镇漫游',
      destination: '中国・云南',
      coverUrl: 'https://picsum.photos/seed/yunnan1/800/600',
      date: DateTime(2024, 3, 15),
      photos: List.generate(
        10,
        (i) => Photo(
          id: '5_$i',
          url: 'https://picsum.photos/seed/yunnan${i + 1}/1200/900',
          thumbnailUrl: 'https://picsum.photos/seed/yunnan${i + 1}/400/300',
          title: '云南第${i + 1}天',
          location: ['丽江', '大理', '束河古镇', '洱海', '玉龙雪山'][i % 5],
          takenAt: DateTime(2024, 3, 15 + i ~/ 2),
        ),
      ),
    ),
  ];
}
