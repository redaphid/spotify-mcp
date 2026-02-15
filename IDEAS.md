# Spotify Vector Store - Ideas

## Goal
Build a vector store of Spotify track data that enables semantic search queries like:
- "hardstyle remix of emo songs I like"
- "dark techno tracks with high energy"
- "shoegaze songs that would sound good as hardstyle"
- "sad songs with fast tempo"

## Datasets Available

| Dataset | Tracks | Size | Location |
|---|---|---|---|
| 600K tracks (1922-2021) | 586,672 | 106 MB | `data/spotify-600k-tracks.csv` |
| 114K tracks (125 genres) | 114,000 | 19 MB | `data/spotify-114k-tracks.csv` |

### Fields in 600K dataset
`id`, `name`, `artists`, `id_artists`, `release_date`, `popularity`, `duration_ms`, `explicit`, `danceability`, `energy`, `key`, `loudness`, `mode`, `speechiness`, `acousticness`, `instrumentalness`, `liveness`, `valence`, `tempo`, `time_signature`

### Fields in 114K dataset
Same audio features as above, plus: `album_name`, `track_genre`

### What's missing
- No lyrics, descriptions, moods, tags, reviews, or prose
- No genre labels in the 600K set
- No album name in the 600K set
- Track name + artist alone don't carry enough semantic meaning for embeddings ("All The Small Things by blink-182" doesn't tell an embedding model it's fast, punky, nostalgic, angsty)

### Important context
Spotify deprecated their Audio Features, Audio Analysis, and Recommendations API endpoints in November 2024. These pre-collected datasets are now the only source for audio features. Can't collect fresh data.

---

## Approaches to Make It Searchable

### Option 1: Synthesize Text Descriptions (Recommended starting point)
Use the audio features + metadata to generate a natural language description for each track, then embed that text.

**Example output:**
> "All The Small Things by blink-182 (album: Enema of the State, genre: pop-punk). High energy (0.9), fast tempo (148 BPM), high valence/happiness (0.82), loud (-4.2 dB), low acousticness. A fast, upbeat, energetic pop-punk track with driving energy."

**Pros:**
- Works for all 600K+ tracks with no external API calls
- Deterministic - just a template/function over the existing data
- Cheap and fast to generate
- Gives embedding models enough context to understand vibes

**Cons:**
- Template-generated text is repetitive, may not differentiate well in embedding space
- Doesn't capture cultural context (e.g. "this is a 2000s emo classic")
- Genre labels only available for 114K subset

**Implementation:**
- Write a function that maps audio feature ranges to descriptive words
- e.g. energy > 0.8 = "high energy", valence < 0.3 = "melancholic", tempo > 140 = "fast"
- Concatenate: `"{track} by {artist}. {genre}. {energy_desc}, {tempo_desc}, {mood_desc}..."`
- Embed with a text embedding model
- Store in vector DB

### Option 2: Hybrid Embedding (Text + Numeric Features)
Combine a text embedding (from track name + artist + genre) with the raw numeric audio features as a separate vector or metadata filter.

**Pros:**
- Can query by vibes ("sad emo songs") AND filter by numbers (tempo > 140, energy > 0.7)
- Numeric features are precise - no information loss from text conversion
- Some vector DBs (Cloudflare Vectorize, Pinecone, Weaviate) support metadata filtering natively

**Cons:**
- More complex to implement and query
- Text embedding still has the "not enough context" problem without enrichment
- Two different similarity spaces to combine

**Implementation:**
- Text embedding from synthesized description (Option 1)
- Store audio features as metadata/payload
- Query: embed search text, find nearest neighbors, then filter/re-rank by audio feature ranges

### Option 3: Enrich with Lyrics
Join with the Spotify Million Song Dataset (57K tracks with lyrics, CC0 license, on HuggingFace).

**Pros:**
- Lyrics carry massive semantic signal ("I'm not okay" is clearly emo without any metadata)
- Great for mood/theme-based search

**Cons:**
- Only covers ~57K tracks (~10% of the 600K dataset)
- Lyrics are copyrighted content - legal gray area for storage/embedding
- Requires joining datasets on track name + artist (fuzzy matching needed)

**Dataset:** `https://huggingface.co/datasets/sebastiandizon/spotify-million-song`

### Option 4: LLM-Generated Tags / Descriptions
Feed batches of (track name, artist, genre, audio features) to an LLM and have it generate rich mood/vibe/subgenre/cultural tags.

**Example prompt:**
> Given this track: "Helena" by My Chemical Romance, genre: emo, energy: 0.88, valence: 0.28, tempo: 150. Generate tags for mood, subgenre, cultural context, and what kind of listener would enjoy this.

**Example output:**
> Tags: emo, post-hardcore, theatrical, dramatic, angsty, 2000s, mall emo, dark, intense, headbanging, My Chemical Romance, Three Cheers era. Mood: cathartic anger, bittersweet. Cultural: MTV era emo, Hot Topic, warped tour. Similar vibes: AFI, The Used, Senses Fail.

**Pros:**
- Richest possible text for embeddings
- Captures cultural context that audio features can't
- LLM "knows" what genres/artists sound like from training data

**Cons:**
- Expensive at scale: 600K tracks x ~500 tokens each = ~300M tokens
- At Haiku pricing (~$0.25/M input, $1.25/M output) that's still ~$200-400
- Slow - would need batching and rate limiting
- Could hallucinate genre/tag info for obscure tracks

**Cost reduction ideas:**
- Only do this for the 114K dataset with genre labels (cheaper, already has genre)
- Use a cheaper model (Haiku) for tagging
- Generate tags only, not full prose (fewer output tokens)
- Batch tracks by genre for better context

### Option 5: Combination Approach (Best Quality)
Layer multiple approaches:

1. **Base layer:** Synthesized text descriptions from audio features (Option 1) - covers all tracks
2. **Enrichment layer:** LLM-generated tags for the 114K genre-labeled subset (Option 4)
3. **Bonus layer:** Lyrics for the ~57K tracks where available (Option 3)
4. **Query layer:** Hybrid search with metadata filtering on raw audio features (Option 2)

This gives you the best of all worlds but is the most complex to build.

---

## Vector Store Backend Options

| Backend | Pros | Cons |
|---|---|---|
| **Cloudflare Vectorize** | Already in your stack, serverless, metadata filtering | Relatively new, size limits |
| **SQLite + sqlite-vss** | Local, no infra, free | Limited scale, no hosted option |
| **Pinecone** | Battle-tested, great filtering | Paid, external dependency |
| **Chroma** | Local-first, easy Python API | Less mature for production |
| **pgvector (Postgres)** | Full SQL power, can self-host | Need to run Postgres |

---

## Embedding Model Options

| Model | Dimensions | Speed | Quality | Cost |
|---|---|---|---|---|
| **Cloudflare Workers AI** (@cf/baai/bge-base-en-v1.5) | 768 | Fast | Good | Free tier |
| **OpenAI text-embedding-3-small** | 1536 | Fast | Great | $0.02/M tokens |
| **Voyage AI** | 1024 | Fast | Great for code/tech | $0.10/M tokens |
| **Local (sentence-transformers)** | 384-768 | Slow | Good | Free |

---

## MVP Plan
1. Start with **Option 1** (synthesized descriptions) on the **114K dataset** (has genres)
2. Use **Cloudflare Vectorize** + **Workers AI embedding model** (already in your stack)
3. Build a simple search endpoint: text query → embedding → nearest neighbors
4. Test with queries from `MUSIC_PREFERENCES.md` ("hardstyle versions of emo songs I like")
5. Iterate: add LLM tags (Option 4) for tracks where search quality is weak
