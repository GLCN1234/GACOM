/// One ordered block of curriculum content: a topic name plus its real
/// generated_questions (question/options/answer schema, matching exactly
/// what's stored in institution_curricula.generated_questions). Every
/// game engine that supports real subject content (Signal Run, Drone
/// Breach, Signal Match, Vault Break) takes a `List<TopicBlock>` of this
/// exact type — defined once here so a TopicBlock built from real
/// curriculum data can be handed to any of them interchangeably.
class TopicBlock {
  const TopicBlock({required this.topicName, required this.questions});
  final String topicName;
  final List<Map<String, dynamic>> questions;
}
