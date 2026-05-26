-- Sahara Club Spa - Enriquecimiento de servicios desde el PDF oficial
-- Pobla description completa, benefits[] y recommended_for[] por cada servicio.
-- Match por (name, category) para distinguir servicios homónimos (ej. "Sahara Soul" masaje vs "Sahara Soul Facial").
-- NO toca precios ni duraciones.
-- contraindications quedan vacías (las llena Sahara después con criterio médico).

-- =============================================================
-- MASAJES (10)
-- =============================================================

update public.services set
  description = 'El masaje de la casa. El ritual que abrió la puerta entre cuerpo y alma. Un masaje de pies a cabeza diseñado para llevar al cuerpo a un estado de descanso real. A través de maniobras envolventes, respiración consciente y un ritmo terapéutico profundo, aquí el cuerpo aprende a soltar.',
  benefits = ARRAY['descanso real','liberación de tensión','regulación del sistema nervioso','respiración consciente'],
  recommended_for = ARRAY['pausar','regular','estrés','primera visita','clásico','volver a habitarse']
where name = 'Sahara Soul' and category = 'Masajes';

update public.services set
  description = 'Un método propio creado por Jochebed. Un encuentro completo con el cuerpo donde se le escucha, se le abraza y se le devuelve calma. Cada toque tiene un propósito: recordarle que ya no tiene que sostener nada. En este espacio, el cuerpo entiende que todo está bien.',
  benefits = ARRAY['presencia integral','contención emocional','calma profunda','método de la casa'],
  recommended_for = ARRAY['experiencia exclusiva','reconexión','método signature']
where name = 'Amazing Experience' and category = 'Masajes';

update public.services set
  description = 'Cuando el cuerpo habla, la terapeuta escucha. Este masaje nace de la capacidad de palpar el cuerpo y leer la emoción. La terapeuta siente, escucha y responde a lo que el cuerpo necesita en ese momento. No sigue una secuencia fija: sigue la sabiduría corporal del paciente.',
  benefits = ARRAY['masaje adaptativo','lectura corporal','liberación emocional'],
  recommended_for = ARRAY['dolores localizados','sobrecargas emocionales','transición','momentos difíciles']
where name = 'La Magia de Sentir' and category = 'Masajes';

update public.services set
  description = 'El masaje que abre la puerta emocional. Un ritual profundo enfocado en pectorales, brazos, manos y cuello que estimula ganglios linfáticos, libera el pecho, activa y relaja el timo (centro inmunológico y emocional). Es un espacio para sentir, soltar y permitir.',
  benefits = ARRAY['apertura emocional','sistema inmunológico','liberación pectoral','estimulación linfática'],
  recommended_for = ARRAY['carga emocional','duelo','ansiedad','sistema inmune','apertura']
where name = 'Caricia al Corazón' and category = 'Masajes';

update public.services set
  description = 'Cuando descansas las extremidades, descansa el sistema nervioso. Brazos, manos, piernas y pies concentran terminaciones nerviosas y carga emocional. Este masaje profundo libera tensión acumulada, mejora la circulación y devuelve sensación de ligereza y presencia.',
  benefits = ARRAY['ligereza','circulación','descanso nervioso','presencia'],
  recommended_for = ARRAY['estrés mental','sobrecarga laboral','cansancio crónico','piernas pesadas']
where name = 'Raíces de Calma' and category = 'Masajes';

update public.services set
  description = 'Liberar la mente, creando espacio interno. Un masaje enfocado en cráneo, rostro y cuello que libera tensiones profundas del sistema nervioso central. Al relajar la musculatura superior y las fascias craneales, se crea un efecto de vacío mental, claridad y descanso profundo.',
  benefits = ARRAY['vacío mental','claridad','descanso profundo','liberación craneal'],
  recommended_for = ARRAY['mente acelerada','insomnio','tensión craneal','dolor de cabeza']
where name = 'Ritual Cráneo Facial' and category = 'Masajes';

update public.services set
  description = 'Fuerza con presencia. Profundidad con cuidado. Para cuerpos que necesitan ir más profundo. Un masaje intenso, firme y sostenido, con ventosas y trabajo corporal consciente. No es suave. Es preciso. El cuerpo se siente más liviano.',
  benefits = ARRAY['tejido profundo','ventosas','ligereza','intensidad consciente'],
  recommended_for = ARRAY['cuerpo cargado','rigidez muscular','dolores profundos','necesidad de intensidad']
where name = 'Descarga Consciente' and category = 'Masajes';

update public.services set
  description = 'Drenar para sanar. Mover para vivir. Un drenaje linfático consciente que activa ganglios, estimula el sistema inmune y apoya procesos de depuración física y emocional. A través de movimientos rítmicos y respiración guiada, el cuerpo entra en un estado de ligereza, desinflamación y renovación interna.',
  benefits = ARRAY['drenaje linfático','desinflamación','renovación','ligereza'],
  recommended_for = ARRAY['retención de líquidos','sistema inmune','depuración','post-procedimiento','desinflamación']
where name = 'Linfa en Movimiento' and category = 'Masajes';

update public.services set
  description = 'El poder del calor consciente. A través de piedras calientes y movimientos circulares, el calor penetra el tejido muscular, relaja profundamente y mejora la circulación. El cuerpo se rinde. La mente se apaga.',
  benefits = ARRAY['piedras calientes','calor profundo','contención','circulación'],
  recommended_for = ARRAY['tensiones profundas','necesidad de contención','frío','clima frío']
where name = 'Calor que Abraza' and category = 'Masajes';

update public.services set
  description = 'Sostener a quien sostiene vida. Un masaje amoroso y seguro para mamás embarazadas. Enfocado en espalda baja, caderas, brazos y drenaje de piernas. Ayuda a liberar tensión, mejorar la circulación y crear un espacio de descanso y conexión profunda con el cuerpo y el bebé.',
  benefits = ARRAY['seguro para embarazo','espalda baja','drenaje de piernas','conexión con bebé'],
  recommended_for = ARRAY['embarazo','prenatal','mamás','espalda baja embarazo']
where (name = 'Creando Vida' or name ilike '%Creando Vida%') and category = 'Masajes';

-- =============================================================
-- EXPERIENCIAS & METODOLOGÍA (Rituales combinados masajes)
-- =============================================================

update public.services set
  description = 'Drenar primero. Descansar después. Una combinación de Linfa en Movimiento y Sahara Soul. Primero activamos el sistema linfático; después llevamos al cuerpo a un descanso profundo. Sensación de limpieza interna, ligereza y paz sostenida.',
  benefits = ARRAY['limpieza interna','ligereza','paz sostenida','drenaje + descanso'],
  recommended_for = ARRAY['post viaje','retención líquidos','reset','desinflamación']
where name = 'Descanso Sagrado';

update public.services set
  description = 'Cuando el calor y la calma se encuentran. Una experiencia que combina Sahara Soul con piedras calientes. Relajación profunda, contención emocional y una sensación de paz que permanece más allá de la sesión.',
  benefits = ARRAY['relajación profunda','contención emocional','paz duradera','calor + descanso'],
  recommended_for = ARRAY['descanso','estrés alto','clima frío','regalo']
where name = 'Alma en Paz';

update public.services set
  description = 'La bienvenida a un cuerpo relajado. Paquete de tres masajes diseñados para acompañar al cuerpo en su proceso natural de liberación y descanso. Cada sesión se realiza cada tres semanas o cada mes. Recorrido natural: primer masaje liberador, segundo más fluido, tercero descanso total.',
  benefits = ARRAY['paquete 3 sesiones','continuidad','descanso sostenido','introducción a Sahara'],
  recommended_for = ARRAY['primera visita','introducción Sahara','plan continuo','suscripción']
where name ilike 'Welcome to the Oasis%' or name ilike '%Oasis%';

update public.services set
  description = 'Una experiencia. Cinco momentos. Un antes y un después. Metodología insignia de Sahara Club. Un ritual creado para llevar al cuerpo, paso a paso, a un estado de descanso profundo, claridad interna y paz sostenida. Incluye Caricia al Corazón, Amazing Experience, Ritual Cráneo Facial, Raíces de Calma, Alma en Paz y un masaje a elegir. No es una suma de tratamientos: es una metodología que transforma la forma en que habitas tu cuerpo.',
  benefits = ARRAY['ritual insignia','5 sesiones combinadas','transformación profunda','descanso sostenido'],
  recommended_for = ARRAY['experiencia signature','regalo premium','transformación','reset total']
where name ilike 'Metodología Sahara Ritual%' or name ilike '%Ritual de Relajación%';

update public.services set
  description = 'Tu cuerpo. Tu ritmo. Tu experiencia. Acompañamiento diseñado completamente a tu medida. Elegimos juntos los masajes, la frecuencia y el tiempo. Algunas personas repiten el mismo ritual mes a mes, otras combinan experiencias. En Sahara Club, no hay una sola forma correcta. Inversión personalizada — recepción te dará el monto en breve.',
  benefits = ARRAY['personalizado','flexible','tu ritmo','plan a medida'],
  recommended_for = ARRAY['cliente frecuente','plan mensual','customización total']
where name ilike 'Relajación Personalizada%';

-- =============================================================
-- FACIALES (9)
-- =============================================================

update public.services set
  description = 'El facial de la casa. Regreso a la piel · Limpieza consciente. Ritual de limpieza profunda que devuelve a la piel su equilibrio natural. Incluye una mascarilla de autor Sahara elaborada con algas y activos 100% naturales, libres de químicos y disruptores hormonales. Cada sesión se adapta a lo que tu piel necesita hoy: hidratación, regulación o rejuvenecimiento.',
  benefits = ARRAY['limpieza profunda','mascarilla de autor','100% natural','sin disruptores hormonales'],
  recommended_for = ARRAY['mantenimiento piel','primera vez facial','piel sana','clásico facial']
where name = 'Sahara Soul Facial' and category = 'Faciales';

update public.services set
  description = 'Limpieza profunda + tecnología consciente. Parte de la base del Sahara Soul Facial y se eleva integrando tecnología estética seleccionada con intención. Incluye limpieza profunda, mascarilla personalizada, ultrasonido y/o radiofrecuencia. La piel se siente limpia, firme, luminosa y profundamente cuidada.',
  benefits = ARRAY['ultrasonido','radiofrecuencia','firmeza','luminosidad'],
  recommended_for = ARRAY['firmeza','antienvejecimiento','tecnología no invasiva','glow']
where name = 'Sahara Soul Deluxe' and category = 'Faciales';

update public.services set
  description = 'Glow total · Piel renovada. Facial mega completo que combina limpieza profunda con tecnología hydrafacial, ultrasonido, radiofrecuencia, máscara LED, rodillo frío y mascarilla Sahara. Diseñado para renovar, hidratar, oxigenar y dar luminosidad inmediata. Ideal para eventos, cambios de estación o cuando quieres verte y sentirte espectacular.',
  benefits = ARRAY['hydrafacial','LED','luminosidad inmediata','renovación total'],
  recommended_for = ARRAY['evento','boda','foto importante','glow instantáneo','cambio de estación']
where name = 'Sahara Soul Glowy' and category = 'Faciales';

update public.services set
  description = 'Iluminar, unificar, revitalizar. Luz que se nota. Facial enfocado en piel apagada, manchitas leves y tono disparejo. Incluye limpieza ligera y trabajo con luz y fotorejuvenecimiento. Su intención es iluminar y dar frescura al rostro.',
  benefits = ARRAY['fotorejuvenecimiento','iluminación','unifica tono','frescura'],
  recommended_for = ARRAY['piel apagada','manchas leves','tono disparejo','frescura']
where name = 'Sahara Lum' and category = 'Faciales';

update public.services set
  description = 'La piel también se alimenta de luz. Regeneración celular. Facial donde la protagonista es la energía lumínica. La piel recibe un baño de diferentes frecuencias de luz que estimulan regeneración, equilibrio y calma. Se complementa con mascarilla personalizada.',
  benefits = ARRAY['LED multicolor','regeneración','equilibrio','calma'],
  recommended_for = ARRAY['piel estresada','piel sensible','piel desvitalizada']
where name = 'Baño de Luz' and category = 'Faciales';

update public.services set
  description = 'Drenar, desinflamar, revitalizar. Drenaje linfático facial consciente que activa ganglios, mejora circulación y reduce inflamación. Aporta ligereza al rostro, mejora el contorno y oxigena tejidos.',
  benefits = ARRAY['drenaje facial','desinflama','contorno','oxigenación'],
  recommended_for = ARRAY['bolsas','retención facial','rostro inflamado','contorno definido']
where name ilike 'Linfa en Movimiento%' and category = 'Faciales';

update public.services set
  description = 'Liberar el rostro también libera la mente. Neuro Rejuvenecimiento consciente. Protocolo de movimientos suaves, respiración guiada y presencia corporal para liberar tensión facial asociada a emociones y creencias. Trabajamos rostro completo con enfoque en ojos, mandíbula y frente. Impacto interno y externo.',
  benefits = ARRAY['liberación facial','mandíbula','tensión emocional','rejuvenecimiento natural'],
  recommended_for = ARRAY['bruxismo','mandíbula tensa','ceño fruncido','rejuvenecimiento sin invasivos']
where name = 'Neuro Yoga Facial' and category = 'Faciales';

update public.services set
  description = 'Conciencia + firmeza. Integra Neuro Yoga Facial con electroestimulación y ultrasonido o radiofrecuencia. Primero soltamos la tensión. Después esculpimos. Para quien busca relajación profunda y mayor firmeza sin perder naturalidad.',
  benefits = ARRAY['electroestimulación','firmeza natural','relajación + esculpido'],
  recommended_for = ARRAY['contorno facial','firmeza','antienvejecimiento sin invasivos']
where name = 'Neuro Sculpt Yoga Facial' and category = 'Faciales';

update public.services set
  description = 'Acompañamiento terapéutico. Trabajo enfocado en fascia, linfa y circulación para apoyar procesos de recuperación antes y después de procedimientos estéticos. Ayuda a desinflamar, drenar y acelerar procesos de regeneración.',
  benefits = ARRAY['post-cirugía','desinflama','acelera recuperación','drenaje'],
  recommended_for = ARRAY['post procedimiento estético','recuperación facial','cirugía estética']
where name ilike 'Pre & Post operatorio facial%';

-- =============================================================
-- TECNOLOGÍA FACIAL POR SESIÓN (4)
-- =============================================================

update public.services set
  description = 'Aplicación individual de radiofrecuencia facial. Estimula colágeno y firmeza.',
  benefits = ARRAY['colágeno','firmeza'],
  recommended_for = ARRAY['firmeza facial','antienvejecimiento','tecnología puntual']
where name = 'Radiofrecuencia' and category ilike '%Tecnología Facial%';

update public.services set
  description = 'Aplicación individual de ultrasonido facial. Apoya procesos de reafirmación.',
  benefits = ARRAY['reafirmación','penetración de activos'],
  recommended_for = ARRAY['reafirmación facial','tratamiento puntual']
where name = 'Ultrasonido' and category ilike '%Tecnología Facial%';

update public.services set
  description = 'Mejora tono y textura del rostro y escote. Aplicación de luz IPL para uniformidad.',
  benefits = ARRAY['tono uniforme','textura','manchas','escote'],
  recommended_for = ARRAY['manchas','escote','tono disparejo','antienvejecimiento']
where name ilike 'Fotorejuvenecimiento%';

update public.services set
  description = 'Regeneración y calma. Aplicación de luz LED de diferentes frecuencias para regenerar y suavizar la piel.',
  benefits = ARRAY['regeneración','calma','LED multifrecuencia'],
  recommended_for = ARRAY['piel sensible','complemento','regeneración rápida']
where name = 'Máscara LED';

-- =============================================================
-- RITUALES FACIALES COMBINADOS (3)
-- =============================================================

update public.services set
  description = 'La experiencia facial más completa de Sahara. Liberar · Activar · Regenerar. Un ritual que integra Neuro Yoga Facial con Sahara Soul Deluxe. Primero liberamos tensión muscular y emocional del rostro a través de movimientos conscientes y respiración guiada. Después aplicamos tecnología, activos y luz para potenciar al máximo la absorción y los resultados. La piel se siente abierta, relajada, luminosa y profundamente nutrida.',
  benefits = ARRAY['ritual facial premium','liberación + tecnología','resultado visible','nutrición profunda'],
  recommended_for = ARRAY['cambio visible','experiencia profunda','combinación completa','regalo premium facial']
where name = 'The Facial Experience';

update public.services set
  description = 'Experiencia signature de cuidado continuo. Método de cuidado progresivo de 4 meses (una sesión al mes) que combina Neuro Yoga Facial, Sahara Soul Deluxe, Sahara Glowy y Neuro Yoga Sculpt. Incluye guía para casa con rutinas faciales conscientes, respiraciones y prácticas de reprogramación de creencias. Para quienes desean un cambio sostenido y profundo.',
  benefits = ARRAY['proceso 4 meses','guía para casa','cambio sostenido','combina 4 técnicas'],
  recommended_for = ARRAY['transformación facial','proceso continuo','plan mensual','cambio profundo']
where name ilike 'Metodología Sahara Facial%';

update public.services set
  description = 'Tu piel · Tu necesidad · Tu ritual. Experiencia facial diseñada completamente a tu medida. Después de una breve evaluación, integramos los faciales y tecnologías que mejor respondan a tu piel en ese momento. Inversión personalizada — recepción te dará el monto en breve.',
  benefits = ARRAY['personalizado','evaluación previa','ritual único'],
  recommended_for = ARRAY['no sé qué elegir','acompañamiento facial','personalizado']
where name ilike 'Glow Personalizado%';

-- =============================================================
-- MOLDEO CONSCIENTE (3)
-- =============================================================

update public.services set
  description = 'Drenar · Activar · Reorganizar · Moldear con amor. Trabajo corporal que no busca castigar el cuerpo, sino apoyar sus procesos naturales, mejorar circulación, liberar congestión, estimular tejido y acompañar la reorganización. Cada sesión integra drenaje linfático consciente, maderoterapia, 30 minutos de aparatología localizada y respiración guiada. No busca quitar: busca enseñarle al cuerpo a reorganizarse.',
  benefits = ARRAY['drenaje linfático','maderoterapia','aparatología localizada','reorganización corporal'],
  recommended_for = ARRAY['moldeo corporal','desinflamación','definición','plan progresivo','reorganización']
where name = 'Transformación Total';

update public.services set
  description = 'Acompañamiento terapéutico. Trabajo enfocado en fascia, linfa y circulación para apoyar procesos antes y después de procedimientos estéticos corporales. Ayuda a desinflamar, drenar, disminuir molestias y acelerar recuperación.',
  benefits = ARRAY['post-cirugía corporal','desinflama','acelera recuperación','reduce molestias'],
  recommended_for = ARRAY['post lipo','post procedimiento corporal','recuperación corporal']
where name ilike 'Pre & Post operatorio corporal%';

update public.services set
  description = 'Protocolo a tu medida. Después de una evaluación, diseñamos un protocolo corporal personalizado integrando trabajo manual, tecnologías, respiración consciente y frecuencia ideal. Para quienes desean un acompañamiento real y progresivo. Inversión personalizada — recepción te dará el monto en breve.',
  benefits = ARRAY['evaluación previa','protocolo a medida','plan progresivo'],
  recommended_for = ARRAY['acompañamiento corporal','plan personalizado','frecuencia ideal']
where name ilike 'Metodología Corporal Personalizada%';

-- =============================================================
-- TECNOLOGÍA CORPORAL POR SESIÓN (6)
-- =============================================================

update public.services set
  description = 'Estimulación localizada. Apoya la movilización de grasa localizada de forma no invasiva. Ideal para zonas específicas donde se busca apoyar procesos de moldeo.',
  benefits = ARRAY['movilización de grasa','no invasivo','aplicación localizada'],
  recommended_for = ARRAY['grasa localizada','moldeo por zona']
where name ilike 'Lipoláser%' or name ilike 'Lipolaser%';

update public.services set
  description = 'Movilización de tejido. Tecnología que apoya la descomposición de grasa localizada y mejora textura de la piel.',
  benefits = ARRAY['descomposición de grasa','mejora textura'],
  recommended_for = ARRAY['adiposidad localizada','textura corporal']
where name ilike 'Cavitación%';

update public.services set
  description = 'Reafirmación y moldeo. Apoya procesos de firmeza y reorganización del tejido corporal.',
  benefits = ARRAY['firmeza','reorganización del tejido'],
  recommended_for = ARRAY['flacidez','reafirmación corporal']
where name = 'Ultrasonido' and category ilike '%Corporal%';

update public.services set
  description = 'Firmeza y elasticidad. Estimula producción de colágeno, mejora tono y calidad de piel.',
  benefits = ARRAY['colágeno','elasticidad','calidad piel'],
  recommended_for = ARRAY['flacidez corporal','calidad de piel','antienvejecimiento corporal']
where name = 'Radiofrecuencia' and category ilike '%Corporal%';

update public.services set
  description = 'Estimulación muscular. Electroestimulación que activa músculo, tonifica y fortalece.',
  benefits = ARRAY['electroestimulación','tonificación muscular'],
  recommended_for = ARRAY['tono muscular','definición','complemento ejercicio']
where name ilike 'Body Sculpt%';

update public.services set
  description = 'Técnica manual de origen ancestral que utiliza instrumentos de madera diseñados para activar circulación, movilizar tejido adiposo y favorecer el drenaje linfático.',
  benefits = ARRAY['técnica ancestral','circulación','drenaje','manual sin tecnología'],
  recommended_for = ARRAY['drenaje linfático','moldeo natural','sin aparatología']
where name ilike 'Maderoterapia%';

-- =============================================================
-- EXPERIENCIAS FUSIONADAS (11)
-- =============================================================

update public.services set
  description = 'Rostro y cuerpo en equilibrio. Combina Sahara Soul Masaje y Sahara Soul Facial. Relaja el cuerpo, limpia la piel y devuelve sensación de balance general. Ideal para una pausa consciente o como primera experiencia Sahara.',
  benefits = ARRAY['cuerpo + rostro','balance general','primera experiencia'],
  recommended_for = ARRAY['primera vez','día spa','regalo','balance']
where name ilike 'Sahara DAY SPA%' or name ilike 'Sahara Day Spa%';

update public.services set
  description = 'Drenar · Regenerar · Iluminar. Combina Linfa en Movimiento Corporal con Baño de Luz Facial. Apoya la desinflamación, activa la circulación y estimula la regeneración celular. El cuerpo se siente ligero. El rostro se ve luminoso.',
  benefits = ARRAY['drenaje + luz','ligereza','luminosidad','regeneración celular'],
  recommended_for = ARRAY['desinflamación + glow','post viaje','combinación cuerpo-rostro']
where name ilike 'Luz en movimiento%' and category ilike '%Fusionada%';

update public.services set
  description = 'Soltar · Sentir · Suavizar. Integra Raíces de Calma, Caricia al Corazón y Neuro Yoga Facial. Libera tensión de extremidades, abre el pecho y suaviza el rostro. Ideal para estrés emocional, sensibilidad y necesidad de contención.',
  benefits = ARRAY['liberación emocional','suavizar rostro','triple ritual'],
  recommended_for = ARRAY['estrés emocional','sensibilidad','contención','momentos difíciles']
where name ilike 'Calma para el ALMA%' or name ilike 'Calma para el Alma%';

update public.services set
  description = 'Fuerza consciente. Combina Descarga Consciente, ventosas y maderoterapia para activar circulación y liberar capas profundas de tensión. Ideal para cuerpos cargados, rigidez muscular o sensación de estancamiento.',
  benefits = ARRAY['ventosas','maderoterapia','tejido profundo','liberación intensa'],
  recommended_for = ARRAY['cuerpo cargado','rigidez muscular','estancamiento']
where name ilike 'Liberación de raíz%';

update public.services set
  description = 'Descanso profundo + iluminación. Integra Calor que Abraza, Baño de Luz Roja Corporal y Sahara Glowy. Lleva al cuerpo a un estado profundo de relajación y al rostro la luminosidad total. Ideal cuando necesitas regresar a ti.',
  benefits = ARRAY['calor + luz','descanso máximo','glow total','autoamor'],
  recommended_for = ARRAY['reset profundo','regreso a ti','autoamor','experiencia premium']
where name ilike 'Volver a mí%';

update public.services set
  description = 'Cuerpo ligero · Rostro relajado · Luz total. Experiencia diseñada para antes de un evento, sesión de fotos o momento importante. Integra Transformación Total, Neuro Yoga Facial y Baño de Luz Facial. Resultado: cuerpo más ligero, rostro relajado, piel luminosa, energía ordenada.',
  benefits = ARRAY['pre-evento','cuerpo + rostro + luz','ligereza total'],
  recommended_for = ARRAY['evento','foto','boda','ocasión especial']
where name ilike 'Glow & Flow%';

update public.services set
  description = 'Experiencia en pareja. Masaje en pareja Sahara Soul, masaje cráneo facial. Incluye copa de vino y chocolates. Un espacio para conectar, relajarse y compartir.',
  benefits = ARRAY['en pareja','vino y chocolates','conexión'],
  recommended_for = ARRAY['pareja','aniversario','regalo romántico','cita especial']
where name ilike 'Feel In Love%' or name ilike 'Feel in Love%';

update public.services set
  description = 'Antes del sí. Combina Sahara Soul Masaje, Linfa en Movimiento y Neuro Yoga Facial. Deja el cuerpo ligero y el rostro relajado y luminoso. Ideal para futuras novias.',
  benefits = ARRAY['pre-boda','ligereza','rostro luminoso'],
  recommended_for = ARRAY['novia','pre-boda','antes del sí']
where name ilike 'Bride to be%';

update public.services set
  description = 'Celebración privada. Experiencia diseñada a la medida para grupos de 4 hasta 16 personas. Opción de cerrar el spa para el grupo. Inversión personalizada — recepción te dará el monto en breve.',
  benefits = ARRAY['grupo privado','spa cerrado','despedida'],
  recommended_for = ARRAY['despedida soltera','grupo amigas','celebración','novia + amigas']
where name ilike 'Squad of the bride%';

update public.services set
  description = 'Cumpleaños consciente para una persona. Incluye Sahara Soul Masaje, Neuro Yoga Facial, Mascarilla Sahara y meditación guiada para iniciar un nuevo año.',
  benefits = ARRAY['cumpleaños','meditación guiada','nuevo ciclo personal'],
  recommended_for = ARRAY['cumpleaños','regalo cumpleaños','nuevo ciclo']
where name ilike 'Vuelta al Sol%';

update public.services set
  description = 'Celebrar la amistad. Experiencia para venir con amigas o amigos a celebrar el arte de existir y apapacharse. Se diseña a la medida combinando masajes y faciales. Inversión personalizada — recepción te dará el monto en breve.',
  benefits = ARRAY['grupo amigas','customización','celebración'],
  recommended_for = ARRAY['amigas','grupo','celebración informal']
where name ilike 'Share Love%';

-- =============================================================
-- EXPERIENCIAS EN COLABORACIÓN (2)
-- =============================================================

update public.services set
  description = 'Respirar · Sentir · Descansar. La experiencia inicia en Soulab con una sesión de respiración consciente y meditación guiada. Continúa en Sahara Club con Sahara Soul Masaje. Recorrido para regular el sistema nervioso, soltar carga mental y llevar al cuerpo a descanso profundo.',
  benefits = ARRAY['Soulab + Sahara','respiración + masaje','reset mental'],
  recommended_for = ARRAY['saturación','cansancio mental','desconexión']
where name ilike 'Mind & Body Reset%' or name ilike 'Mind and Body Reset%';

update public.services set
  description = 'Respiración · Cuerpo · Recuperación. Experiencia integral de tres fases: Soulab (respiración y meditación), Sahara Club (masaje corporal) y Motus (sauna infrarrojo + tina de agua fría). Reset que trabaja desde adentro hacia afuera.',
  benefits = ARRAY['Soulab + Sahara + Motus','3 fases','sauna + frío','reset total'],
  recommended_for = ARRAY['reset profundo','experiencia completa','tres espacios','contrastes térmicos']
where name ilike 'RE - NACER%' or name ilike 'Re-nacer%' or name ilike 'Renacer%';

-- =============================================================
-- SAHARA HOUSE (1)
-- =============================================================

update public.services set
  description = 'Hospedaje + experiencias de bienestar. Quédate con nosotros, elige tu experiencia Sahara Spa favorita y convierte tu descanso en un retiro personal. Espacios para 1 hasta 10 personas. Ideal para escapadas, celebraciones conscientes, retiros personales y experiencias privadas. Combinable con masajes, faciales, rituales y experiencias Sahara. Inversión personalizada — recepción te dará el monto en breve.',
  benefits = ARRAY['hospedaje','retiro privado','combinable con servicios','1 a 10 personas'],
  recommended_for = ARRAY['retiro','escapada','celebración privada','grupos pequeños']
where name ilike 'Sahara House%' or category ilike '%Sahara House%';

-- =============================================================
-- VERIFICACIÓN FINAL
-- =============================================================

select
  count(*) filter (where description is not null and description <> '') as con_descripcion,
  count(*) filter (where coalesce(array_length(benefits, 1), 0) > 0) as con_benefits,
  count(*) filter (where coalesce(array_length(recommended_for, 1), 0) > 0) as con_recommended,
  count(*) as total_servicios
from public.services;
