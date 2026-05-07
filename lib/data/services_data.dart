class SpaService {
  final String name;
  final String description;
  final String details;

  const SpaService({
    required this.name,
    required this.description,
    required this.details,
  });
}

class ServiceCategory {
  final String title;
  final String subtitle;
  final List<SpaService> services;

  const ServiceCategory({
    required this.title,
    required this.subtitle,
    required this.services,
  });
}

final List<ServiceCategory> servicesData = [
  ServiceCategory(
    title: "Masajes",
    subtitle: "El lenguaje más antiguo del cuerpo es el contacto. Cada masaje es una conversación silenciosa entre tus tejidos y la presencia. Un espacio para soltar, respirar y volver a habitarte.",
    services: [
      SpaService(
        name: "Sahara Soul",
        description: "El masaje de la casa. El ritual que abrió la puerta entre cuerpo y alma. Sahara Soul es un masaje de pies a cabeza diseñado para llevar al cuerpo a un estado de descanso real. A través de maniobras envolventes, respiración consciente y un ritmo terapéutico profundo, aquí el cuerpo aprende a soltar. Ideal para quien necesita pausar, regular y volver a habitarse.",
        details: "Tiempo 60 min Inversión \$1089\nTiempo 90 min Inversión \$1590\nTiempo 120 min Inversión \$1970",
      ),
      SpaService(
        name: "Amazing Experience · Creado por Jochebed",
        description: "Un método propio. Un encuentro completo con el cuerpo. Aquí se le escucha, se le abraza y se le devuelve calma. Cada toque tiene un propósito: recordarle que ya no tiene que sostener nada. Un masaje que recorre todo el cuerpo con presencia, cuidado y sentido. En este espacio, el cuerpo entiende que todo está bien.",
        details: "Tiempo 90 min Inversión \$1777",
      ),
      SpaService(
        name: "La Magia de Sentir",
        description: "Cuando el cuerpo habla, la terapeuta escucha. Este masaje nace de la capacidad desarrollada en Sahara Club de palpar el cuerpo y leer la emoción. La terapeuta siente, escucha y responde a lo que el cuerpo necesita en ese momento. No sigue una secuencia fija: sigue la sabiduría corporal del paciente. Ideal para dolores localizados, sobrecargas emocionales o momentos de transición. Aquí, el cuerpo guía el camino.",
        details: "Tiempo 30 min Inversión \$555\nTiempo 60 min Inversión \$1111\nTiempo 90 min Inversión \$1680",
      ),
      SpaService(
        name: "Caricia al Corazón",
        description: "El masaje que abre la puerta emocional. Un ritual profundo enfocado en pectorales, brazos, manos y cuello, estimula ganglios linfáticos, libera el pecho, activa y relaja el timo, centro inmunológico y emocional. Este masaje toca fibras más allá del músculo. Muchas personas liberan emociones sin saber por qué. Y no necesitan saberlo. Es un espacio para sentir, soltar y permitir.",
        details: "Tiempo 60 min Inversión \$950",
      ),
      SpaService(
        name: "Raíces de Calma",
        description: "Cuando descansas las extremidades, descansa el sistema nervioso. Brazos, manos, piernas y pies concentran terminaciones nerviosas y carga emocional. Este masaje profundo libera tensión acumulada, mejora la circulación y devuelve sensación de ligereza y presencia. Ideal para personas con estrés mental, sobrecarga laboral o cansancio crónico. Descansar aquí, se siente en todo el cuerpo.",
        details: "Tiempo 60 min Inversión \$950",
      ),
      SpaService(
        name: "Ritual Cráneo Facial",
        description: "Liberar la mente, creando espacio interno. Un masaje enfocado en cráneo, rostro y cuello que libera tensiones profundas del sistema nervioso central. Al relajar la musculatura superior y las fascias craneales, se crea un efecto de vacío mental, claridad y descanso profundo. Ideal para quienes viven con la mente acelerada o necesitan abrir espacio para nuevos pensamientos.",
        details: "Tiempo 60 min Inversión \$950",
      ),
      SpaService(
        name: "Descarga Consciente",
        description: "Fuerza con presencia. Profundidad con cuidado. Para cuerpos que necesitan ir más profundo. Un masaje intenso, firme y sostenido, con ventosas y trabajo corporal consciente. No es suave. Es preciso. El cuerpo se siente más liviano.",
        details: "Tiempo 60 min Inversión \$1265\nTiempo 90 min Inversión \$1777",
      ),
      SpaService(
        name: "Linfa en Movimiento",
        description: "Drenar para sanar. Mover para vivir. Un drenaje linfático consciente que activa ganglios, estimula el sistema inmune y apoya procesos de depuración física y emocional. A través de movimientos rítmicos y respiración guiada, el cuerpo entra en un estado de ligereza, desinflamación y renovación interna.",
        details: "Tiempo 60 min Inversión \$999",
      ),
      SpaService(
        name: "Calor que Abraza",
        description: "El poder del calor consciente. A través de piedras calientes y movimientos circulares, el calor penetra el tejido muscular, relaja profundamente y mejora la circulación. El cuerpo se rinde. La mente se apaga. Ideal para tensiones profundas y necesidad de contención.",
        details: "Tiempo 60 min Inversión \$1380\nTiempo 90 min Inversión \$1999",
      ),
      SpaService(
        name: "Creando Vida (Masaje prenatal)",
        description: "Sostener a quien sostiene vida. Un masaje amoroso y seguro para mamás embarazadas. Enfocado en espalda baja, caderas, brazos y drenaje de piernas. Ayuda a liberar tensión, mejorar la circulación y crear un espacio de descanso y conexión profunda con el cuerpo y el bebé. Aquí, el cuerpo se siente acompañado.",
        details: "Tiempo 60 min Inversión \$999",
      ),
    ],
  ),
  ServiceCategory(
    title: "Metodología Sahara",
    subtitle: "Rituales que nacen de la unión de varios toques. Recorridos diseñados para llevar al cuerpo de la tensión al descanso sostenido.",
    services: [
      SpaService(
        name: "Descanso Sagrado",
        description: "Drenar primero. Descansar después. Una combinación de Linfa en Movimiento y Sahara Soul. Primero activamos el sistema linfático; después llevamos al cuerpo a un descanso profundo. El resultado: sensación de limpieza interna, ligereza y paz sostenida.",
        details: "Tiempo 90 min Inversión \$1499\nTiempo 120 min Inversión \$1799",
      ),
      SpaService(
        name: "Alma en Paz",
        description: "Cuando el calor y la calma se encuentran. Una experiencia que combina Sahara Soul con piedras calientes. Relajación profunda, contención emocional y una sensación de paz que permanece más allá de la sesión. Un regalo para el cuerpo... y para el alma.",
        details: "Tiempo 60 min Inversión \$1222",
      ),
      SpaService(
        name: "Welcome to the Oasis",
        description: "La bienvenida a un cuerpo relajado. Un paquete de tres masajes diseñados para acompañar al cuerpo en su proceso natural de liberación y descanso. Cada sesión se realiza cada tres semanas o cada mes, permitiendo que el cuerpo no vuelva a tensarse y que el descanso se sostenga en el tiempo.",
        details: "Tiempo 60 min Inversión \$2999\nTiempo 90 min Inversión \$4299",
      ),
      SpaService(
        name: "Metodología Sahara · Ritual de Relajación Profunda",
        description: "Una experiencia. Cinco momentos. Un antes y un después. Esta es la metodología insignia de Sahara Club. Un ritual creado para llevar al cuerpo, paso a paso, a un estado de descanso profundo, claridad interna y paz sostenida. \n1. Caricia al Corazón\n2. Amazing Experience\n3. Ritual Cráneo Facial\n4. Raíces de Calma\n5. Alma en Paz\n6. Elige tu masaje favorito.",
        details: "Inversión \$5499",
      ),
      SpaService(
        name: "Relajación Personalizada",
        description: "Tu cuerpo. Tu ritmo. Tu experiencia. Un acompañamiento diseñado completamente a tu medida. Aquí elegimos juntos los masajes, la frecuencia y el tiempo, respetando lo que tu cuerpo necesita... y lo que tú deseas.",
        details: "La inversión se define de manera personalizada.",
      ),
    ]
  ),
  ServiceCategory(
    title: "Faciales",
    subtitle: "Tu piel escucha. Recuerda. Responde. Aquí no corregimos rostros. Los acompañamos a regresar a su equilibrio natural.",
    services: [
      SpaService(
        name: "Sahara Soul",
        description: "El facial de la casa. Regreso a la piel · Limpieza consciente. Ritual de limpieza profunda que devuelve a la piel su equilibrio natural. Incluye una de nuestras mascarillas de autor Sahara, elaboradas con algas y activos 100% naturales, libres de químicos y disruptores hormonales. Cada sesión se adapta a lo que tu piel necesita hoy: hidratación, regulación o rejuvenecimiento. Ideal para mantener la piel sana, limpia y en balance.",
        details: "Tiempo 90 min Inversión \$1190",
      ),
      SpaService(
        name: "Sahara Soul Deluxe",
        description: "Limpieza profunda + tecnología consciente. Parte de la base del Sahara Soul y se eleva integrando tecnología estética seleccionada con intención. Incluye: limpieza profunda, mascarilla personalizada, ultrasonido y/o radiofrecuencia. La piel se siente limpia, firme, luminosa y profundamente cuidada.",
        details: "Tiempo 90 a 120 min Inversión \$1450",
      ),
      SpaService(
        name: "Sahara Soul Glowy",
        description: "Glow total · Piel renovada. Facial mega completo que combina: Limpieza profunda con tecnología hydrafacial. Ultrasonido. Radiofrecuencia. Máscara LED. Rodillo frío. Mascarilla Sahara. Diseñado para renovar, hidratar, oxigenar y dar luminosidad inmediata. Ideal para eventos, cambios de estación o cuando quieres verte y sentirte espectacular.",
        details: "Tiempo 120 min Inversión \$1799",
      ),
      SpaService(
        name: "Sahara Lum",
        description: "Iluminar, unificar, revitalizar. Luz que se nota. Facial enfocado en piel apagada, manchitas leves y tono disparejo. Incluye limpieza ligera y trabajo con luz y fotorejuvenecimiento. No profundiza en extracción. Su intención es iluminar y dar frescura al rostro.",
        details: "Tiempo 90 min Inversión \$1550",
      ),
      SpaService(
        name: "Baño de Luz",
        description: "La piel también se alimenta de luz. Regeneración celular. Facial donde la protagonista es la energía lumínica. La piel recibe un baño de diferentes frecuencias de luz que estimulan regeneración, equilibrio y calma. Se complementa con mascarilla personalizada. Ideal para pieles estresadas, sensibles o desvitalizadas.",
        details: "Tiempo 60 min Inversión \$888",
      ),
      SpaService(
        name: "Linfa en Movimiento Facial",
        description: "Drenar, desinflamar, revitalizar. Drenaje linfático facial consciente que activa ganglios, mejora circulación y reduce inflamación. Aporta ligereza al rostro, mejora el contorno y oxigena tejidos. Ideal para bolsas, retención de líquidos y rostro inflamado.",
        details: "Tiempo 30 min Inversión \$699",
      ),
      SpaService(
        name: "Neuro Yoga Facial",
        description: "Liberar el rostro también libera la mente. Neuro Rejuvenecimiento consciente. Protocolo de movimientos suaves, respiración guiada y presencia corporal para liberar tensión facial asociada a emociones y creencias. Trabajamos rostro completo con enfoque en ojos, mandíbula y frente. Impacto interno y externo.",
        details: "Tiempo 60 min Inversión \$999",
      ),
      SpaService(
        name: "Neuro Sculpt Yoga Facial",
        description: "Conciencia + firmeza. Integra Neuro Yoga Facial con electroestimulación y ultrasonido o radiofrecuencia. Primero soltamos la tensión. Después esculpimos. Ideal para quien busca relajación profunda y mayor firmeza sin perder naturalidad.",
        details: "Tiempo 90 min Inversión \$1299",
      ),
      SpaService(
        name: "Pre & Post operatorio facial",
        description: "Acompañamiento terapéutico. Trabajo enfocado en fascia, linfa y circulación para apoyar procesos de recuperación antes y después de procedimientos estéticos. Ayuda a desinflamar, drenar y acelerar procesos de regeneración.",
        details: "Tiempo 60 min Inversión \$999",
      ),
      SpaService(
        name: "Tecnología facial por sesión",
        description: "Aplicaciones individuales: Radiofrecuencia (45 min, \$999), Ultrasonido (45 min, \$999), Fotorejuvenecimiento facial y escote (30 min, \$950), Máscara LED (30 min, \$555).",
        details: "Inversiones variadas",
      ),
      SpaService(
        name: "The Facial Experience",
        description: "La experiencia facial más completa de Sahara. Liberar · Activar · Regenerar. Un ritual que integra Neuro Yoga Facial con Sahara Soul Deluxe. Primero liberamos tensión muscular y emocional del rostro a través de movimientos conscientes y respiración guiada. Después aplicamos tecnología, activos y luz para potenciar al máximo la absorción y los resultados. La piel se siente abierta, relajada, luminosa y profundamente nutrida.",
        details: "Tiempo 150 a 180 min Inversión \$2599",
      ),
      SpaService(
        name: "Metodología Sahara Facial",
        description: "Experiencia signature de cuidado continuo. Es un método de cuidado progresivo, diseñado para acompañar la piel, el rostro y el sistema nervioso a lo largo del tiempo. Se recomienda vivirlo una vez al mes, por al menos 4 meses consecutivos. Incluye Neuro Yoga facial, Sahara Soul Deluxe, Sahara Glowy y Neuro Yoga Sculpt.",
        details: "Inversión \$4850",
      ),
      SpaService(
        name: "Glow Personalizado",
        description: "Tu piel · Tu necesidad · Tu ritual. Una experiencia facial diseñada completamente a tu medida. Después de una breve evaluación, integramos los faciales y tecnologías que mejor respondan a tu piel en ese momento, creando un ritual único para ti.",
        details: "Inversión Personalizada",
      )
    ]
  ),
  ServiceCategory(
    title: "Moldeo Consciente",
    subtitle: "No es reducir. No es castigar. Es reorganizar, drenar, activar y cuidar. Moldear con amor.",
    services: [
      SpaService(
        name: "Transformación Total",
        description: "Drenar · Activar · Reorganizar · Moldear con amor. En Sahara, el trabajo corporal busca apoyar los procesos naturales del cuerpo. Cada sesión integra tecnología estética + trabajo manual + respiración consciente. Apoya procesos de desinflamación, moldeo, mejora de textura y regulación del sistema nervioso.",
        details: "Tiempo 90 min\n1 sesión: \$1500\n4 sesiones: \$5,700\n8 sesiones: \$11,400\n12 sesiones: \$17,100\n16 sesiones: \$22,800\n20 sesiones: \$27,000",
      ),
      SpaService(
        name: "Pre & Post operatorio corporal",
        description: "Acompañamiento terapéutico. Trabajo enfocado en fascia, linfa y circulación para apoyar procesos antes y después de procedimientos estéticos. Ayuda a desinflamar, drenar, disminuir molestias y acelerar recuperación.",
        details: "Tiempo 60 min\n1 sesión: \$999\n5 sesiones: \$4450\n10 sesiones: \$8999",
      ),
      SpaService(
        name: "Metodología Corporal Personalizada",
        description: "Protocolo a tu medida. Después de una evaluación, diseñamos un protocolo corporal personalizado integrando trabajo manual, tecnologías y respiración consciente.",
        details: "Inversión Personalizada",
      ),
      SpaService(
        name: "Tecnología Corporal por Sesión",
        description: "Aplicaciones individuales: LIPOLÁSER (\$850), CAVITACIÓN (\$899), ULTRASONIDO CORPORAL (\$899), RADIOFRECUENCIA CORPORAL (\$999), BODY SCULPT (\$1299), MADEROTERAPIA (\$999).",
        details: "Inversiones variadas",
      ),
    ]
  ),
  ServiceCategory(
    title: "Experiencias Fusionadas",
    subtitle: "Cuando cuerpo, rostro y sistema nervioso se encuentran. Experiencias diseñadas para acompañar procesos específicos de descanso, liberación, iluminación y reconexión.",
    services: [
      SpaService(
        name: "Sahara DAY SPA",
        description: "Rostro y cuerpo en equilibrio. Una experiencia que combina Sahara Soul Masaje y Sahara Soul Facial. Relaja el cuerpo, limpia la piel y devuelve sensación de balance general.",
        details: "Tiempo 150 min Inversión \$2080",
      ),
      SpaService(
        name: "Luz en Movimiento",
        description: "Drenar · Regenerar · Iluminar. Combina Linfa en Movimiento Corporal con Baño de Luz Facial. Apoya la desinflamación, activa la circulación y estimula la regeneración celular.",
        details: "Tiempo 90 min Inversión \$1499",
      ),
      SpaService(
        name: "Calma para el ALMA",
        description: "Soltar · Sentir · Suavizar. Integra Raíces de Calma, Caricia al Corazón y Neuro Yoga Facial. Libera tensión de extremidades, abre el pecho y suaviza el rostro.",
        details: "Tiempo 120 min Inversión \$2099",
      ),
      SpaService(
        name: "Liberación de Raíz",
        description: "Fuerza consciente. Combina Descarga Consciente, ventosas y maderoterapia para activar circulación y liberar capas profundas de tensión.",
        details: "Tiempo 120 min Inversión \$2250",
      ),
      SpaService(
        name: "Volver a Mí",
        description: "Descanso profundo + iluminación. Integra Calor que Abraza, Baño de Luz Roja Corporal y Sahara Glowy. Lleva al cuerpo a un estado profundo de relajación y al rostro la luminosidad total.",
        details: "Tiempo 180 min Inversión \$3999",
      ),
      SpaService(
        name: "Glow & Flow",
        description: "Cuerpo ligero · Rostro relajado · Luz total. Diseñada para antes de un evento. Integra Transformación Total, Neuro Yoga Facial y Baño de Luz Facial.",
        details: "Tiempo 150 min Inversión \$2499",
      ),
      SpaService(
        name: "Feel In Love (Pareja)",
        description: "Experiencia en pareja. Masaje Sahara Soul, masaje cráneo facial, copa de vino y chocolates. Un espacio para conectar y relajarse.",
        details: "Tiempo 60 min \$2399\nTiempo 90 min \$3499",
      ),
      SpaService(
        name: "Bride to be",
        description: "Antes del sí. Combina Sahara Soul Masaje, Linfa en Movimiento y Neuro Yoga Facial. Deja el cuerpo ligero y el rostro relajado y luminoso.",
        details: "Tiempo 120 min Inversión \$1999",
      ),
      SpaService(
        name: "Squad of the bride",
        description: "Celebración privada. Experiencia diseñada a la medida para grupos de 4 hasta 16 personas. Opción de cerrar el spa para el grupo.",
        details: "Inversión por cotización",
      ),
      SpaService(
        name: "Vuelta al Sol",
        description: "Cumpleaños consciente · 1 persona. Incluye Sahara Soul Masaje, Neuro Yoga Facial, Mascarilla Sahara y meditación guiada para iniciar un nuevo año.",
        details: "Tiempo 150 min Inversión \$2499",
      ),
      SpaService(
        name: "Share Love",
        description: "Celebrar la amistad. Una experiencia para venir con amigos a celebrar el arte de existir y apapacharse.",
        details: "Inversión por cotización",
      ),
    ]
  ),
  ServiceCategory(
    title: "Experiencias en Colaboración",
    subtitle: "El bienestar se expande cuando se comparte. Alianzas creadas para llevarte más profundo de lo que un solo espacio podría.",
    services: [
      SpaService(
        name: "Mind & Body Reset",
        description: "Respirar · Sentir · Descansar. La experiencia inicia en Soulab con una sesión de respiración consciente y meditación guiada. Posteriormente continúa en Sahara Club con Sahara Soul Masaje.",
        details: "Tiempo 120 min Inversión \$1799",
      ),
      SpaService(
        name: "RE - NACER",
        description: "Respiración · Cuerpo · Recuperación. Un recorrido de tres fases: 1. Soulab – Masaje interno (respiración y meditación). 2. Sahara Club – Masaje externo (liberación de tensión física). 3. Motus – Recuperación y contrastes (sauna infrarrojo y tina de agua fría).",
        details: "Tiempo 180 min Inversión \$2599",
      ),
    ]
  ),
  ServiceCategory(
    title: "Sahara House",
    subtitle: "Quédate. Descansa. Respira. Elige tu experiencia Sahara Spa favorita y convierte tu estancia en un ritual.",
    services: [
      SpaService(
        name: "Hospedaje + Experiencias de Bienestar",
        description: "Contamos con espacios de hospedaje para 1 hasta 10 personas, ideales para escapadas de descanso, celebraciones conscientes, retiros personales y experiencias privadas. Puedes combinar tu estancia con nuestros rituales.",
        details: "Cotización personalizada",
      ),
    ]
  ),
];
