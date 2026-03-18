import sqlite3, uuid
from datetime import datetime, timedelta

conn = sqlite3.connect('db/gym_app.db')
cur = conn.cursor()

gym_id = 'gym-owner-001'
now = datetime.now()

posts = [
    {
        'id': str(uuid.uuid4()),
        'author_id': '02afacd7-a688-4a7b-a065-e1f01651a5f6',  # Alberto
        'post_type': 'post',
        'content': 'Oggi ho battuto il mio record personale di squat! 140kg x 3 rep. Grazie al mio trainer per la programmazione perfetta.',
        'like_count': 12, 'comment_count': 3,
        'created_at': (now - timedelta(hours=2)).isoformat(),
    },
    {
        'id': str(uuid.uuid4()),
        'author_id': '0d616526-6ef9-4775-b26a-8122dd12189a',  # Marco
        'post_type': 'post',
        'content': 'Primo mese in palestra completato! Non pensavo di riuscire a essere cosi costante. La community qui e fantastica, mi motiva ogni giorno.',
        'like_count': 24, 'comment_count': 5,
        'created_at': (now - timedelta(hours=5)).isoformat(),
    },
    {
        'id': str(uuid.uuid4()),
        'author_id': 'd9ddcb56-7678-4a4c-a1b4-718176017058',  # Luca
        'post_type': 'post',
        'content': 'Qualcuno fa panca il martedi sera? Cerco un partner di allenamento per spotter reciproco. Peso circa 80kg di panca.',
        'like_count': 7, 'comment_count': 8,
        'created_at': (now - timedelta(hours=8)).isoformat(),
    },
    {
        'id': str(uuid.uuid4()),
        'author_id': '07dcf18d-3f5b-4062-bc0e-cf3fc2d0865a',  # x1 (trainer)
        'post_type': 'post',
        'content': 'Reminder: non saltate il riscaldamento! 10 minuti di mobilita prima di allenarvi possono prevenire settimane di infortunio. Il vostro corpo vi ringraziera.',
        'like_count': 31, 'comment_count': 2,
        'created_at': (now - timedelta(hours=12)).isoformat(),
    },
    {
        'id': str(uuid.uuid4()),
        'author_id': '7bdbe01f-55a1-42b1-a810-f5698cfbd06d',  # Alessandro
        'post_type': 'post',
        'content': 'Finalmente riesco a fare 10 trazioni di fila! 3 mesi fa non ne facevo neanche una. La costanza paga sempre.',
        'like_count': 42, 'comment_count': 11,
        'created_at': (now - timedelta(days=1)).isoformat(),
    },
    {
        'id': str(uuid.uuid4()),
        'author_id': 'c4dc1aba-ff2f-4e35-a308-9cc8d6b286ad',  # Giovanni
        'post_type': 'post',
        'content': "Ho provato la nuova area funzionale oggi. Attrezzi top e tanto spazio. Complimenti alla palestra per l'upgrade!",
        'like_count': 18, 'comment_count': 4,
        'created_at': (now - timedelta(days=1, hours=6)).isoformat(),
    },
    {
        'id': str(uuid.uuid4()),
        'author_id': 'gym-owner-001',
        'post_type': 'event',
        'content': "Vi aspettiamo per una giornata di allenamento all'aperto! Workout di gruppo, musica e divertimento. Portate un amico gratis!",
        'event_title': 'Outdoor Workout Day',
        'event_date': (now + timedelta(days=10)).strftime('%Y-%m-%d'),
        'event_time': '10:00',
        'event_location': 'Parco Sempione, Milano',
        'like_count': 55, 'comment_count': 14,
        'is_pinned': True,
        'created_at': (now - timedelta(days=2)).isoformat(),
    },
    {
        'id': str(uuid.uuid4()),
        'author_id': 'ea6fc683-b2d3-42a5-9052-d935381bf77e',  # x3
        'post_type': 'post',
        'content': 'Consigli per migliorare lo stacco da terra? Faccio fatica a superare i 100kg. La schiena tende ad arrotondarsi.',
        'like_count': 5, 'comment_count': 12,
        'created_at': (now - timedelta(days=2, hours=3)).isoformat(),
    },
    {
        'id': str(uuid.uuid4()),
        'author_id': 'ba2ccfec-b8e9-4e79-bf70-7aeec37bfe71',  # x2 (trainer)
        'post_type': 'post',
        'content': "Nuovo programma di corsi a partire da lunedi! Aggiungiamo Yoga alle 7:00 e HIIT alle 19:30. Prenotate dall'app!",
        'like_count': 28, 'comment_count': 6,
        'created_at': (now - timedelta(days=3)).isoformat(),
    },
    {
        'id': str(uuid.uuid4()),
        'author_id': '5ebeab0a-e32b-41c2-97b1-50d46d0857bb',  # x4
        'post_type': 'post',
        'content': 'Dopo 6 mesi di cut, finalmente sono sotto il 12% di body fat. La dieta e stata dura ma i risultati parlano da soli.',
        'like_count': 67, 'comment_count': 15,
        'created_at': (now - timedelta(days=4)).isoformat(),
    },
]

for p in posts:
    cur.execute(
        '''INSERT INTO community_posts
        (id, author_id, gym_id, post_type, content, image_url, event_title, event_date, event_time, event_location,
         quest_xp_reward, quest_deadline, is_pinned, is_deleted, like_count, comment_count, repost_count, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
        (p['id'], p['author_id'], gym_id, p['post_type'], p['content'], p.get('image_url'),
         p.get('event_title'), p.get('event_date'), p.get('event_time'), p.get('event_location'),
         p.get('quest_xp_reward', 0), p.get('quest_deadline'), p.get('is_pinned', False), False,
         p['like_count'], p['comment_count'], 0, p['created_at'], p['created_at']))

post_ids = [p['id'] for p in posts]

comments = [
    (post_ids[0], '0d616526-6ef9-4775-b26a-8122dd12189a', 'Grande Alberto! Prossimo obiettivo 150kg!'),
    (post_ids[0], '07dcf18d-3f5b-4062-bc0e-cf3fc2d0865a', 'Ottimo lavoro! La tecnica era pulitissima oggi.'),
    (post_ids[0], 'd9ddcb56-7678-4a4c-a1b4-718176017058', 'Bestia!'),
    (post_ids[1], '02afacd7-a688-4a7b-a065-e1f01651a5f6', 'Bravo Marco! Continua cosi!'),
    (post_ids[1], '7bdbe01f-55a1-42b1-a810-f5698cfbd06d', 'Il primo mese e il piu difficile, da qui in poi e tutta discesa!'),
    (post_ids[1], 'gym-owner-001', 'Benvenuto nella famiglia!'),
    (post_ids[2], '02afacd7-a688-4a7b-a065-e1f01651a5f6', 'Io ci sono! Faccio circa 85kg. Ti scrivo in DM.'),
    (post_ids[2], '7bdbe01f-55a1-42b1-a810-f5698cfbd06d', 'Anche io disponibile, di solito vengo alle 20.'),
    (post_ids[4], '0d616526-6ef9-4775-b26a-8122dd12189a', 'Pazzesco! Io sono ancora a 5, ma ci arrivo!'),
    (post_ids[4], 'c4dc1aba-ff2f-4e35-a308-9cc8d6b286ad', 'Complimenti! Che programma hai seguito?'),
    (post_ids[7], '07dcf18d-3f5b-4062-bc0e-cf3fc2d0865a', 'Lavora molto sul setup iniziale e sulla posizione delle anche. Registra un video e lo analizziamo insieme!'),
    (post_ids[7], 'ba2ccfec-b8e9-4e79-bf70-7aeec37bfe71', 'Prova a fare pause deadlifts per rinforzare la posizione. 3x5 al 70% con 3 secondi di pausa a meta tibia.'),
    (post_ids[9], '0d616526-6ef9-4775-b26a-8122dd12189a', 'Trasformazione incredibile! Posta qualche foto prima/dopo!'),
    (post_ids[9], 'd9ddcb56-7678-4a4c-a1b4-718176017058', 'Che dieta hai seguito?'),
]

for post_id, author_id, content in comments:
    cur.execute(
        '''INSERT INTO community_comments (post_id, author_id, content, like_count, is_deleted, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?)''',
        (post_id, author_id, content, 0, False, (now - timedelta(hours=1)).isoformat(), (now - timedelta(hours=1)).isoformat()))

conn.commit()
print(f'Inserted {len(posts)} posts and {len(comments)} comments')
conn.close()
