/// Authored English content for Sundial City. Every item has exactly one
/// correct answer. Level: grade 7 to 12.

/// A short letter or paragraph whose five sentences are in the right order.
class SdLetter {
  final String title;
  final List<String> lines;
  const SdLetter(this.title, this.lines);
}

/// A street sign with one or two gaps. [answers] are the tiles for the gaps
/// in order; [wrong] are tiles that fit no gap.
class SdSign {
  final String text;
  final List<String> answers;
  final List<String> wrong;
  const SdSign(this.text, this.answers, this.wrong);

  int get gaps => answers.length;

  List<String> get pieces => text.split('__');

  /// The sentence with the correct words filled in.
  String get solved {
    final List<String> p = pieces;
    final StringBuffer b = StringBuffer();
    for (int i = 0; i < p.length; i++) {
      b.write(p[i]);
      if (i < answers.length) b.write(answers[i]);
    }
    return b.toString();
  }
}

/// Two witness statements. Sentence [bad] of statement B cannot be true if
/// statement A is true.
class SdCase {
  final String title;
  final String nameA;
  final String nameB;
  final List<String> a;
  final List<String> b;
  final int bad;
  final String why;
  const SdCase(this.title, this.nameA, this.nameB, this.a, this.b, this.bad, this.why);
}

/// An unpunctuated sentence with one correct rewrite and two wrong ones.
class SdPunct {
  final String raw;
  final String right;
  final List<String> wrong;
  const SdPunct(this.raw, this.right, this.wrong);
}

/// A sentence with the target word marked as [[word]] and its meaning here.
class SdVocab {
  final String sentence;
  final String right;
  final List<String> wrong;
  const SdVocab(this.sentence, this.right, this.wrong);

  String get word {
    final int a = sentence.indexOf('[[');
    final int b = sentence.indexOf(']]');
    if (a < 0 || b < a) return '';
    return sentence.substring(a + 2, b);
  }

  String get before {
    final int a = sentence.indexOf('[[');
    return a < 0 ? sentence : sentence.substring(0, a);
  }

  String get after {
    final int b = sentence.indexOf(']]');
    return b < 0 ? '' : sentence.substring(b + 2);
  }

  String get plain => '$before$word$after';
}

/// A debate. [cards] has seven cards in this fixed order:
/// 0 claim (right), 1 claim (opposing), 2 evidence (right), 3 evidence (weak
/// or unrelated), 4 evidence (opposing), 5 reasoning (right), 6 reasoning
/// (weak). The only valid argument is cards 0, 2 and 5 in the slots
/// Claim, Evidence, Reasoning.
class SdDebate {
  final String question;
  final String stance;
  final List<String> cards;
  final String why;
  const SdDebate(this.question, this.stance, this.cards, this.why);
}

const List<String> sdDebateSlots = <String>['CLAIM', 'EVIDENCE', 'REASONING'];
const List<int> sdDebateAnswer = <int>[0, 2, 5];

// ---------------------------------------------------------------------------
// Post Office: letter order

const List<SdLetter> sdLetters = <SdLetter>[
  SdLetter('A thank-you letter', <String>[
    "Dear Aunt Folake, thank you for the lovely books you sent me for my birthday.",
    "First, I read the story about the river spirit, and I could not stop laughing.",
    "Then I shared the book of poems with my sister, who now reads one every night.",
    "However, I have not yet finished the atlas because it is so large.",
    "Finally, I promise to write again as soon as I reach the last page.",
  ]),
  SdLetter('A request to the principal', <String>[
    "Dear Principal, I am writing to ask permission to start a reading club at our school.",
    "First, the club would meet every Friday after the last lesson in the library.",
    "Next, each member would borrow one book and tell the group about it the following week.",
    "However, I understand that lending books every week may give the library staff extra work.",
    "Therefore, I will gladly organise the books myself if you agree.",
  ]),
  SdLetter('A school trip', <String>[
    "Last Saturday, our class visited Olumo Rock in Abeokuta.",
    "First, we climbed the stone steps while our guide told us the history of the rock.",
    "Then we rested in a small cave where the people of Egba once hid from their enemies.",
    "However, the climb back down was much harder than the climb up.",
    "In the end, we were tired but happy, and we all agreed it was the best trip of the year.",
  ]),
  SdLetter('How to cook jollof rice', <String>[
    "Jollof rice is easy to cook if you follow these steps.",
    "First, fry the chopped onions in hot oil until they turn soft.",
    "Next, add the blended tomatoes and pepper and let them simmer for twenty minutes.",
    "After that, pour in the washed rice with enough stock to cover it.",
    "Finally, cover the pot and cook on low heat until the rice is soft.",
  ]),
  SdLetter('A complaint to a shop', <String>[
    "Dear Manager, I bought a school bag from your shop on Monday.",
    "On Tuesday, however, the zip broke while I was walking to school.",
    "Therefore, I returned the bag on Wednesday and asked for a replacement.",
    "Unfortunately, the assistant told me that I needed a receipt, which I had lost.",
    "I would be grateful if you could look into the matter and replace the bag.",
  ]),
  SdLetter('An invitation', <String>[
    "Dear Kunle, our school is holding its annual Science Fair next month, and I would like you to come.",
    "To begin with, the fair will open at nine o'clock in the main hall.",
    "After the opening, there will be a quiz competition with prizes for the winners.",
    "Afterwards, everyone will share a simple lunch under the mango tree.",
    "Please tell me by Friday whether you can come, so that I can reserve a seat for you.",
  ]),
  SdLetter('A match report', <String>[
    "The school football final was played on Thursday afternoon.",
    "At first, neither team could score, and the crowd grew restless.",
    "Then, just before half-time, Chidi scored a brilliant goal from the edge of the box.",
    "After the break, the other team fought back and equalised.",
    "In the end, a late penalty gave our school a 2-1 victory.",
  ]),
  SdLetter('Why we should plant trees', <String>[
    "Planting trees is one of the simplest ways to protect our town.",
    "To begin with, trees give shade, which keeps our homes cooler in the dry season.",
    "In addition, their roots hold the soil together and prevent floods during heavy rain.",
    "However, many people cut down trees without planting new ones.",
    "Therefore, every family should plant at least one tree each year.",
  ]),
  SdLetter('An apology', <String>[
    "Dear Mrs Adeyemi, I am sorry for arriving late to your class on Tuesday.",
    "First, I must explain that the bus broke down near the market.",
    "As a result, I had to walk the last two kilometres in the rain.",
    "Although I ran as fast as I could, the lesson had already begun.",
    "I promise that from now on I will leave home thirty minutes earlier.",
  ]),
  SdLetter('A job application', <String>[
    "Dear Sir, I am writing to apply for the position of library assistant advertised in the Daily Star.",
    "Firstly, I am a hard-working student who has helped to run our school library for two years.",
    "Secondly, I can organise books quickly and I know how to use the catalogue system.",
    "Moreover, I am friendly and I enjoy helping younger children to choose books.",
    "I would be happy to attend an interview at any time you choose.",
  ]),
  SdLetter('The tortoise and the crocodile', <String>[
    "One hot afternoon, a tortoise decided to cross the wide river.",
    "First, he asked the crocodile to carry him across on its back.",
    "The crocodile agreed, but halfway across it began to laugh and dive.",
    "Quickly, the tortoise pulled in his head and legs, and the crocodile could not swallow his hard shell.",
    "At last, the angry crocodile spat him out on the far bank, and the tortoise walked home safely.",
  ]),
  SdLetter('The water cycle', <String>[
    "The water cycle is the journey that water takes around the Earth.",
    "First, the heat of the sun turns water from rivers and seas into vapour.",
    "Then the vapour rises and cools, forming clouds high in the sky.",
    "Next, the water in the clouds falls back to the ground as rain.",
    "Finally, the rain flows into rivers, and the cycle begins again.",
  ]),
];

// ---------------------------------------------------------------------------
// Market: sign repair

const List<SdSign> sdSigns = <SdSign>[
  SdSign('Fresh yams __ sold here every Saturday.', <String>['are'], <String>['is', 'am', 'be']),
  SdSign('All customers must wash __ hands before entering.', <String>['their'], <String>['there', "they're", 'them']),
  SdSign('Please keep __ dog on a lead.', <String>['your'], <String>["you're", 'yours', 'you']),
  SdSign('__ is a clinic at the end of this road.', <String>['There'], <String>['Their', "They're", 'These']),
  SdSign("The shop closes __ six o'clock on Sundays.", <String>['at'], <String>['in', 'on', 'to']),
  SdSign('The bus to Ibadan leaves __ half past seven.', <String>['at'], <String>['on', 'in', 'for']),
  SdSign('The meeting will be held __ Tuesday.', <String>['on'], <String>['in', 'at', 'of']),
  SdSign('Please do not park __ front of the gate.', <String>['in'], <String>['on', 'at', 'to']),
  SdSign('We have lived __ Abeokuta since 2015.', <String>['in'], <String>['on', 'to', 'into']),
  SdSign('The library is open __ Monday __ Friday.', <String>['from', 'to'], <String>['with', 'into', 'beside']),
  SdSign('The dog wagged __ tail when it saw us.', <String>['its'], <String>["it's", "its'", 'it']),
  SdSign("__ been a long time since the bell rang.", <String>["It's"], <String>['Its', 'It', 'Is']),
  SdSign('The soup is __ hot to drink.', <String>['too'], <String>['to', 'two', 'tow']),
  SdSign('We bought __ loaves of bread.', <String>['two'], <String>['to', 'too', 'tho']),
  SdSign("__ welcome to join our choir.", <String>["You're"], <String>['Your', 'Yore', 'Youre']),
  SdSign('Please show __ ticket at the gate.', <String>['your'], <String>["you're", 'you', 'yours']),
  SdSign("__ going to open a new bakery here soon.", <String>["They're"], <String>['Their', 'There', 'Theirs']),
  SdSign('Look over __ and you will see the old sundial.', <String>['there'], <String>['their', "they're", "there's"]),
  SdSign('The teachers left __ bags in the staff room.', <String>['their'], <String>['there', "they're", 'them']),
  SdSign('The twins are proud because __ team won the cup.', <String>['their'], <String>['there', "they're", 'theirs']),
  SdSign('Yesterday, the baker __ forty loaves.', <String>['sold'], <String>['sell', 'sells', 'selling']),
  SdSign('Last week, our class __ to the museum.', <String>['went'], <String>['go', 'gone', 'going']),
  SdSign('The bell has already __ twice.', <String>['rung'], <String>['rang', 'ring', 'ringed']),
  SdSign('By the time we arrived, the market __ already closed.', <String>['had'], <String>['has', 'have', 'will']),
  SdSign('Tomorrow, the mayor __ open the new school.', <String>['will'], <String>['did', 'has', 'was']),
  SdSign('The students __ practising since morning.', <String>['have been'], <String>['has been', 'is', 'was']),
  SdSign('While I __ home, it began to rain.', <String>['was walking'], <String>['am walking', 'walk', 'have walked']),
  SdSign('Each of the boys __ a bag.', <String>['has'], <String>['have', 'are', 'were']),
  SdSign('The list of rules __ on the wall.', <String>['is'], <String>['are', 'be', 'am']),
  SdSign('Neither the teacher nor the pupils __ ready.', <String>['were'], <String>['was', 'is', 'be']),
  SdSign('My brother and my sister __ in Lagos.', <String>['live'], <String>['lives', 'living', 'has live']),
  SdSign('Everyone __ welcome at the festival.', <String>['is'], <String>['are', 'am', 'were']),
  SdSign('The news about the match __ good.', <String>['is'], <String>['are', 'were', 'have']),
  SdSign('There __ many reasons to visit the museum.', <String>['are'], <String>['is', 'was', 'has']),
  SdSign('We saw __ elephant at the zoo.', <String>['an'], <String>['a', 'many', 'two']),
  SdSign('She is __ honest girl.', <String>['an'], <String>['a', 'any', 'each']),
  SdSign('My uncle is __ engineer in Lagos.', <String>['an'], <String>['a', 'many', 'two']),
  SdSign('The sun rises in __ east.', <String>['the'], <String>['a', 'an', 'no']),
  SdSign('Three __ are waiting at the gate.', <String>['women'], <String>['woman', 'womans', 'womens']),
  SdSign('Please keep all the __ clean.', <String>['shelves'], <String>['shelfs', 'shelf', 'shelve']),
  SdSign('Many __ crossed the bridge this morning.', <String>['children'], <String>['childs', 'childrens', 'child']),
  SdSign('Please sharpen all the __ before use.', <String>['knives'], <String>['knifes', 'knife', 'knive']),
  SdSign('Both __ were repaired last month.', <String>['bridges'], <String>['bridge', 'bridgs', 'bridgees']),
  SdSign('This road is __ than the old one.', <String>['wider'], <String>['more wide', 'widest', 'wide']),
  SdSign('Of all the girls, Ngozi is the __.', <String>['tallest'], <String>['taller', 'more tall', 'tall']),
  SdSign('We have __ time than we thought.', <String>['less'], <String>['fewer', 'few', 'many']),
  SdSign('There are __ cars on the road today.', <String>['fewer'], <String>['less', 'little', 'much']),
  SdSign('She sings __ than her sister.', <String>['better'], <String>['more good', 'best', 'well']),
  SdSign('Please drive __ near the school.', <String>['carefully'], <String>['careful', 'care', 'carefulness']),
  SdSign('He is a very __ driver.', <String>['careful'], <String>['carefully', 'care', 'carelessly']),
  SdSign('This is __ amazing story, and __ ending will surprise you.', <String>['an', 'its'], <String>['a', "it's", 'it']),
  SdSign('The boys put __ shoes by the door and went __ the garden.', <String>['their', 'into'], <String>['there', "they're", 'among']),
  SdSign('There __ two buses, but __ drivers are late.', <String>['are', 'their'], <String>['is', 'there', "they're"]),
  SdSign('My sister __ to school every day, but yesterday she __ the bus.', <String>['walks', 'missed'], <String>['walk', 'miss', 'missing']),
  SdSign('If it __ tomorrow, we will stay at home.', <String>['rains'], <String>['rained', 'will rain', 'is rain']),
  SdSign('I have never __ such a beautiful sunset.', <String>['seen'], <String>['saw', 'see', 'seeing']),
  SdSign('He __ his homework before he went out to play.', <String>['had finished'], <String>['has finished', 'finishes', 'finishing']),
  SdSign('The prize was given to Ada and __.', <String>['him'], <String>['he', 'his', 'himself']),
  SdSign('Share the sweets between Ada and __.', <String>['me'], <String>['I', 'my', 'mine']),
];

// ---------------------------------------------------------------------------
// Courthouse: witness statements. Statement A is certain; one sentence in
// statement B cannot be true.

const List<SdCase> sdCases = <SdCase>[
  SdCase(
    'The missing mangoes',
    'Mama Nkechi, the stall owner',
    'Mr Salami, the night guard',
    <String>[
      'I closed my stall at six o\'clock on Friday evening.',
      'Twelve baskets of mangoes were under a green cloth when I left.',
      'I walked home with my daughter, and we were home before dark.',
    ],
    <String>[
      'I started my shift at seven o\'clock on Friday evening.',
      'The green cloth was lying on the ground at eight o\'clock.',
      'Only nine baskets were left under the stall.',
      'Mama Nkechi was still sitting at her stall when I arrived at seven.',
    ],
    3,
    'Mama Nkechi closed at six and went home, so she could not still be at her stall at seven.',
  ),
  SdCase(
    'The broken window',
    'Mrs Okoro, the teacher',
    'Segun, the caretaker',
    <String>[
      'The glass was broken between eleven o\'clock and noon.',
      'During that hour, all Class Five pupils were writing an exam in the hall.',
      'The exam hall has only one door, and I stood at it the whole time.',
    ],
    <String>[
      'At eleven o\'clock, I was cleaning the staff room.',
      'At about half past eleven, I heard a loud crash near the science block.',
      'I ran there and found a football on the floor.',
      'I saw three Class Five pupils running away from the science block.',
    ],
    3,
    'All of Class Five were in the exam hall during that hour, so none of them could be running away from the science block.',
  ),
  SdCase(
    'The stolen bicycle',
    'Tunde, the owner',
    'Mrs Danjuma, the orange seller',
    <String>[
      'I left my red bicycle outside the post office at two o\'clock.',
      'The bicycle had a yellow bell on the handlebar.',
      'I was inside the post office for ten minutes only.',
    ],
    <String>[
      'I sell oranges across the street from the post office.',
      'At five past two, I saw a boy wheel a red bicycle away.',
      'The bicycle had a blue bell on the handlebar.',
      'The boy was wearing a green cap.',
    ],
    2,
    'Tunde says the bell was yellow, so a bicycle with a blue bell cannot be his.',
  ),
  SdCase(
    'The late bus',
    'Musa, the driver',
    'Mrs Eze, the passenger',
    <String>[
      'The bus left Ibadan at eight o\'clock in the morning.',
      'The journey to Lagos usually takes two hours.',
      'We stopped only once, at a petrol station, for fifteen minutes.',
    ],
    <String>[
      'I sat in the front row, next to the window.',
      'The bus reached Lagos before nine o\'clock.',
      'We stopped for petrol one time.',
      'The driver was polite to everyone.',
    ],
    1,
    'A bus that left at eight and needs two hours cannot arrive before nine, and it also stopped for fifteen minutes.',
  ),
  SdCase(
    'The library book',
    'Mr Eke, the librarian',
    'Amaka, the student',
    <String>[
      'The library opens at eight o\'clock and closes at four o\'clock.',
      'On Monday, a student returned Things Fall Apart at half past three.',
      'I stamped the book and placed it on the return shelf.',
    ],
    <String>[
      'I went to the library after my last lesson on Monday.',
      'I returned Things Fall Apart at five o\'clock.',
      'The librarian stamped the book in front of me.',
      'The book was only one day late, so I paid no fine.',
    ],
    1,
    'The library closes at four, so nobody could return a book there at five o\'clock.',
  ),
  SdCase(
    'The naming ceremony',
    'Mama Put, the cook',
    'Pastor Dayo, the guest',
    <String>[
      'I cooked rice for the village naming ceremony on Sunday.',
      'The ceremony started at noon and ended at four.',
      'I served two hundred guests, and nobody was left hungry.',
    ],
    <String>[
      'I arrived at the ceremony at one o\'clock.',
      'The rice was served by a group of young women.',
      'The ceremony was held on Saturday under a big tent.',
      'I left at about three o\'clock.',
    ],
    2,
    'The cook says the ceremony was on Sunday, so it cannot have been held on Saturday.',
  ),
  SdCase(
    'The fisherman',
    'Yinka, the boatman',
    'Mr Femi, the villager',
    <String>[
      'The river was calm at dawn, and I started fishing at six.',
      'I caught nothing until nine o\'clock.',
      'I sold my fish at the market by noon.',
    ],
    <String>[
      'I walked along the river at seven o\'clock.',
      'The morning mist was thick over the water.',
      'I saw Yinka pulling a full net of fish out of the water.',
      'A few women were washing clothes on the bank.',
    ],
    2,
    'Yinka caught nothing until nine, so he could not have been pulling in a full net at seven.',
  ),
  SdCase(
    'The school trophy',
    'Coach Ade, the sports teacher',
    'Rose, the cleaner',
    <String>[
      'The trophy was kept in a glass cabinet in the head teacher\'s office.',
      'Only the head teacher and I have keys to the office.',
      'On Thursday, the head teacher was away at a meeting in Abuja all day.',
    ],
    <String>[
      'I cleaned the head teacher\'s office on Thursday morning.',
      'The door was locked, so I asked Coach Ade to open it.',
      'The head teacher let me in himself and watched me clean.',
      'The trophy was still in the cabinet when I finished.',
    ],
    2,
    'The head teacher was in Abuja all day Thursday, so he could not have let the cleaner in.',
  ),
  SdCase(
    'The football match',
    'Mr Kalu, the referee',
    'Ifeoma, the spectator',
    <String>[
      'The match started at four o\'clock on a dry, sunny afternoon.',
      'The pitch was hard and dusty.',
      'We played for ninety minutes without a break for rain.',
    ],
    <String>[
      'I sat on the stand behind the goal.',
      'The home team scored in the first ten minutes.',
      'The players were slipping in the mud because of the heavy rain.',
      'The crowd cheered loudly all afternoon.',
    ],
    2,
    'The referee says the afternoon was dry and the pitch dusty, so there could be no mud or heavy rain.',
  ),
  SdCase(
    'The shared taxi',
    'Mr Bashir, the taxi driver',
    'Hauwa, the passenger',
    <String>[
      'My taxi seats five people, including me.',
      'On Tuesday I left the park with every seat taken.',
      'I dropped the first passenger at the bank.',
    ],
    <String>[
      'I sat in the back seat, next to the window.',
      'There were six passengers in the taxi besides the driver.',
      'I was the second person to get out.',
      'The road to the market was very busy.',
    ],
    1,
    'The taxi seats five people including the driver, so it can carry only four passengers.',
  ),
  SdCase(
    'The missing homework',
    'Mr Obi, the mathematics teacher',
    'Bisi, the pupil',
    <String>[
      'I collected the mathematics homework on Wednesday morning.',
      'Thirty pupils were present, and I received thirty books.',
      'I locked the books in my cupboard before lunch.',
    ],
    <String>[
      'I handed in my book on Wednesday morning.',
      'Only twenty pupils were in class that day.',
      'I saw Mr Obi put the books in his cupboard.',
      'My book had a blue cover.',
    ],
    1,
    'Mr Obi says thirty pupils were present, so it cannot be true that only twenty were in class.',
  ),
  SdCase(
    'The market fire drill',
    'Mrs Lawal, the market chairwoman',
    'Chika, the trader',
    <String>[
      'The fire drill took place on Monday at nine o\'clock in the morning.',
      'The bell rang three times to start the drill.',
      'Every trader left the market in less than five minutes.',
    ],
    <String>[
      'My stall sells cloth near the north gate.',
      'I heard the bell ring three times.',
      'It took more than twenty minutes before the last trader left the market.',
      'I carried my money box with me as I left.',
    ],
    2,
    'Mrs Lawal says every trader left in less than five minutes, so it cannot have taken more than twenty.',
  ),
];

// ---------------------------------------------------------------------------
// School: punctuation

const List<SdPunct> sdPunct = <SdPunct>[
  SdPunct(
    'our teacher asked where is the chalk',
    'Our teacher asked, "Where is the chalk?"',
    <String>['Our teacher asked "where is the chalk?"', 'Our teacher asked, "Where is the chalk."'],
  ),
  SdPunct(
    'we bought rice beans yams and plantain at the market',
    'We bought rice, beans, yams and plantain at the market.',
    <String>['We bought rice beans yams, and plantain at the market.', 'We bought, rice beans yams and plantain at the market.'],
  ),
  SdPunct(
    'the girls bags are on the table',
    "The girls' bags are on the table.",
    <String>["The girl's bags are on the table.", "The girls bag's are on the table."],
  ),
  SdPunct(
    'its a long walk but its worth it',
    "It's a long walk, but it's worth it.",
    <String>["Its a long walk, but its worth it.", "It's a long walk but its worth it."],
  ),
  SdPunct(
    'after the rain stopped we went out to play',
    'After the rain stopped, we went out to play.',
    <String>['After the rain stopped we went, out to play.', 'After, the rain stopped we went out to play.'],
  ),
  SdPunct(
    'can you help me carry these books',
    'Can you help me carry these books?',
    <String>['Can you help me carry these books.', 'can you help me carry these books?'],
  ),
  SdPunct(
    'mr johnson our new principal lives in ibadan',
    'Mr Johnson, our new principal, lives in Ibadan.',
    <String>['Mr Johnson our new principal, lives in Ibadan.', 'Mr Johnson, our new principal lives in Ibadan.'],
  ),
  SdPunct(
    'i said i would come but he did not believe me',
    'I said I would come, but he did not believe me.',
    <String>['I said, I would come but he did not believe me.', 'i said I would come, but he did not believe me.'],
  ),
  SdPunct(
    'we are late said ada',
    '"We are late," said Ada.',
    <String>['"We are late". said Ada.', '"We are late." said Ada.'],
  ),
  SdPunct(
    'although it was late nobody wanted to leave',
    'Although it was late, nobody wanted to leave.',
    <String>['Although it was late nobody, wanted to leave.', 'Although, it was late nobody wanted to leave.'],
  ),
  SdPunct(
    'what a beautiful dress',
    'What a beautiful dress!',
    <String>['What a beautiful dress?', 'what a beautiful dress!'],
  ),
  SdPunct(
    'kemi asked did you finish your homework',
    'Kemi asked, "Did you finish your homework?"',
    <String>['Kemi asked "did you finish your homework?"', 'Kemi asked, "Did you finish your homework".'],
  ),
  SdPunct(
    'on monday we visited lagos abuja and kano',
    'On Monday we visited Lagos, Abuja and Kano.',
    <String>['On monday we visited Lagos Abuja and Kano.', 'On Monday we visited, Lagos, Abuja and Kano.'],
  ),
  SdPunct(
    'the dog wagged its tail and barked',
    'The dog wagged its tail and barked.',
    <String>["The dog wagged it's tail and barked.", "The dog wagged its' tail and barked."],
  ),
  SdPunct(
    'where did you put my shoes asked dad',
    '"Where did you put my shoes?" asked Dad.',
    <String>['"Where did you put my shoes." asked Dad.', '"Where did you put my shoes?", asked Dad.'],
  ),
  SdPunct(
    'when we reached the village the chief welcomed us',
    'When we reached the village, the chief welcomed us.',
    <String>['When we reached the village the chief, welcomed us.', 'When we reached, the village the chief welcomed us.'],
  ),
  SdPunct(
    'tunde who is my cousin plays the drums',
    'Tunde, who is my cousin, plays the drums.',
    <String>['Tunde who is my cousin, plays the drums.', 'Tunde, who is my cousin plays the drums.'],
  ),
  SdPunct(
    'dont forget to bring your pencil ruler and eraser',
    "Don't forget to bring your pencil, ruler and eraser.",
    <String>["Dont forget to bring your pencil, ruler and eraser.", "Don't forget to bring, your pencil ruler and eraser."],
  ),
  SdPunct(
    'the boy asked may i borrow your pen',
    'The boy asked, "May I borrow your pen?"',
    <String>['The boy asked, "may I borrow your pen?"', 'The boy asked "May I borrow your pen"?'],
  ),
  SdPunct(
    'she was tired so she went to bed early',
    'She was tired, so she went to bed early.',
    <String>['She was tired so, she went to bed early.', 'She was tired so she went, to bed early.'],
  ),
  SdPunct(
    'i love reading poems stories and plays',
    'I love reading poems, stories and plays.',
    <String>['I love reading poems stories, and plays.', 'I love, reading poems, stories and plays.'],
  ),
  SdPunct(
    'the mens coats hung by the door',
    "The men's coats hung by the door.",
    <String>["The mens' coats hung by the door.", "The mens coats hung by the door."],
  ),
];

// ---------------------------------------------------------------------------
// Library: vocabulary in context

const List<SdVocab> sdVocab = <SdVocab>[
  SdVocab('The old man was [[reluctant]] to leave his village, so he packed slowly.', 'unwilling', <String>['excited', 'allowed']),
  SdVocab('The teacher gave a [[concise]] summary that fitted on one page.', 'short and clear', <String>['long and detailed', 'difficult to read']),
  SdVocab('Her [[diligent]] work earned her the top prize.', 'hard-working', <String>['careless', 'lucky']),
  SdVocab('The crowd grew [[restless]] as the speaker kept them waiting.', 'unable to stay calm or still', <String>['quiet and happy', 'very hungry']),
  SdVocab('Clean water was [[scarce]] during the dry season.', 'hard to find', <String>['very cold', 'plentiful']),
  SdVocab('He gave a [[sincere]] apology and meant every word.', 'honest and heartfelt', <String>['loud and angry', 'short and hurried']),
  SdVocab('The mayor tried to [[persuade]] the council to build a new road.', 'convince by giving reasons', <String>['force by threats', 'forget about']),
  SdVocab('The explorers faced [[hostile]] weather on the mountain.', 'unfriendly and harsh', <String>['warm and gentle', 'unusual but pleasant']),
  SdVocab('It is [[essential]] to read the question carefully before you answer.', 'absolutely necessary', <String>['slightly helpful', 'impossible']),
  SdVocab('The judge was [[impartial]] and did not favour either side.', 'fair, not taking sides', <String>['angry and loud', 'unprepared']),
  SdVocab('The market was [[bustling]] with traders and shoppers.', 'full of busy activity', <String>['completely empty', 'closed for the day']),
  SdVocab('After the long walk, she felt [[weary]].', 'very tired', <String>['very hungry', 'very proud']),
  SdVocab('The company will [[expand]] its business to three new towns.', 'grow larger', <String>['close down', 'sell off']),
  SdVocab('The villagers were [[grateful]] for the clean well.', 'thankful', <String>['worried', 'surprised']),
  SdVocab('His answer was [[vague]], and nobody understood what he wanted.', 'unclear', <String>['rude', 'correct']),
  SdVocab('The athlete showed great [[endurance]] in the long race.', 'the ability to keep going', <String>['speed at the start', 'good luck']),
  SdVocab('She is very [[modest]] and never boasts about her success.', 'humble', <String>['selfish', 'afraid of the dark']),
  SdVocab('The farmer\'s harvest was [[abundant]] this year.', 'plentiful', <String>['poor', 'late']),
  SdVocab('The soldiers decided to [[retreat]] when the storm grew worse.', 'move back', <String>['attack', 'celebrate']),
  SdVocab('The new rule is [[mandatory]] for every student.', 'required', <String>['optional', 'forbidden']),
  SdVocab('The boy was [[bewildered]] by the confusing map.', 'puzzled', <String>['delighted', 'sleepy']),
  SdVocab('Her [[candid]] reply surprised the committee.', 'frank and honest', <String>['secret', 'angry']),
  SdVocab('The [[bank]] of the river was muddy after the flood.', 'the land along the side of a river', <String>['a place where money is kept', 'a long row of seats']),
  SdVocab('The judge read out the [[sentence]]: five years in prison.', 'the punishment given by a court', <String>['a group of words with a subject and a verb', 'a kind of book']),
  SdVocab('The council promised to [[address]] the complaints one by one.', 'deal with', <String>['write on an envelope', 'ignore']),
  SdVocab('The [[bark]] of the old tree was rough and dry.', 'the outer covering of a tree', <String>['the sound a dog makes', 'a small sailing boat']),
];

// ---------------------------------------------------------------------------
// Town Hall: the debate

const List<SdDebate> sdDebates = <SdDebate>[
  SdDebate(
    'Should our school keep a daily 15-minute reading time?',
    'Speak FOR the daily reading time.',
    <String>[
      'Our school should keep the daily 15-minute reading time.',
      'Our school should end the daily reading time.',
      'Last term, Class 8 pupils who read every day scored higher in English than classmates who rarely read.',
      'Our school has a blue gate and a large mango tree.',
      'Reading time takes 15 minutes away from other lessons each day.',
      'Higher English scores show that regular reading builds vocabulary and understanding, so a daily reading time helps every pupil learn better.',
      'Reading time has existed for many years, so it must stay.',
    ],
    'The claim says what to do, the evidence is a fact that supports it, and the reasoning explains why that fact supports the claim.',
  ),
  SdDebate(
    'Should the town ban plastic bags in the market?',
    'Speak FOR the ban.',
    <String>[
      'The town should ban plastic bags in the market.',
      'The town should allow plastic bags to stay in the market.',
      'After last year\'s clean-up, volunteers found that plastic bags blocked eleven of the town\'s twelve drains.',
      'Plastic bags come in many colours, including white, black and blue.',
      'Plastic bags are cheaper for traders than paper bags.',
      'Blocked drains cause flooding in the rainy season, so removing plastic bags would protect homes and shops from floods.',
      'Bags are very common in the market, so people should stop using them.',
    ],
    'Blocked drains are a fact that supports the ban, and flooding explains why the ban would help.',
  ),
  SdDebate(
    'Should pupils use calculators when they are learning basic arithmetic?',
    'Speak AGAINST calculators in basic arithmetic lessons.',
    <String>[
      'Pupils should not use calculators when they are learning basic arithmetic.',
      'Pupils should use calculators in every arithmetic lesson.',
      'In a school survey, pupils who always used calculators took twice as long to solve 7 x 8 without one.',
      'Calculators were invented many years ago.',
      'Calculators give the correct answer to long sums in a few seconds.',
      'Pupils who cannot work out simple sums in their heads will struggle in later subjects, so they must practise by hand before using a calculator.',
      'Calculators need batteries, so they should not be allowed.',
    ],
    'The survey is evidence that calculators weaken mental arithmetic, and the reasoning links that weakness to later subjects.',
  ),
  SdDebate(
    'Should the town build a library or a football pitch on the empty plot?',
    'Speak FOR the library.',
    <String>[
      'The town should build a library on the empty plot.',
      'The town should build a football pitch on the empty plot.',
      'The only library in town has forty seats, but over three hundred students need a quiet place to study each week.',
      'The empty plot is next to a road where many yellow buses pass.',
      'The town football team has won three cups in the last two years.',
      'A larger library would give hundreds of students a place to study, which meets a need the town cannot meet now.',
      'Libraries are quiet places, and quiet places are always better than noisy ones.',
    ],
    'The shortage of seats is the evidence, and the reasoning shows how a new library would meet that need.',
  ),
  SdDebate(
    'Should secondary schools start later in the morning?',
    'Speak FOR a later start.',
    <String>[
      'Secondary schools should start later in the morning.',
      'Secondary schools should start earlier in the morning.',
      'A study of teenagers found that those who slept at least eight hours scored higher on tests than those who slept six hours.',
      'Some schools have a green uniform and others have a brown uniform.',
      'Starting early means pupils can finish lessons before the afternoon heat.',
      'Teenagers who sleep longer concentrate better, so a later start would give them the sleep they need to learn well.',
      'Many pupils like to stay in bed, so the school should do what pupils like.',
    ],
    'The sleep study is the evidence, and the reasoning connects more sleep to better learning and a later start.',
  ),
  SdDebate(
    'Should every household in the village keep a small vegetable garden?',
    'Speak FOR the gardens.',
    <String>[
      'Every household in the village should keep a small vegetable garden.',
      'Households should buy all their vegetables from the market instead.',
      'A family that grew its own vegetables spent about half as much on food each month as a family that bought everything.',
      'Many vegetables are green, and some are red.',
      'The market sells fresh vegetables every morning.',
      'Spending less on food leaves families more money for school fees and health care, so a garden improves a household\'s wellbeing.',
      'Farmers have always grown vegetables, so every household has to do the same.',
    ],
    'Lower food spending is the evidence, and the reasoning shows what the saved money can do.',
  ),
  SdDebate(
    'Should the council repair the footbridge or the market roof first?',
    'Speak FOR repairing the footbridge first.',
    <String>[
      'The council should repair the footbridge before the market roof.',
      'The council should repair the market roof before the footbridge.',
      'Two children slipped through broken planks on the footbridge last month on their way to school.',
      'The footbridge is painted brown and the market roof is painted grey.',
      'Traders lose goods to rain every week because the market roof leaks.',
      'A broken footbridge puts children\'s safety at risk now, and safety must come before the loss of goods, so it should be repaired first.',
      'Bridges are longer than roofs, so they must be more important.',
    ],
    'The accident is the evidence, and the reasoning explains why safety comes before lost goods.',
  ),
];
