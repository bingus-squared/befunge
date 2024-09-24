use crate::sim::GridUpdate;
use slab::Slab;
use std::collections::{BTreeMap, HashMap, HashSet};

pub trait Subscriber: Send {
    fn notify(&self, updates: Vec<GridUpdate>);
}

pub struct SubscriptionManager<S: Subscriber> {
    pub subscribers: Slab<(HashSet<(usize, usize)>, S)>,
    pub chunks: HashMap<(usize, usize), HashSet<usize>>,
}

impl<S: Subscriber> SubscriptionManager<S> {
    pub fn new() -> SubscriptionManager<S> {
        SubscriptionManager {
            subscribers: Slab::new(),
            chunks: HashMap::new(),
        }
    }

    pub fn subscribe(&mut self, subscriber: S) -> usize {
        let id = self.subscribers.insert((HashSet::new(), subscriber));
        id
    }

    pub fn unsubscribe(&mut self, id: usize) {
        for chunk in self.subscribers.remove(id).0 {
            self.chunks.get_mut(&chunk).unwrap().remove(&id);
            if self.chunks[&chunk].len() == 0 {
                self.chunks.remove(&chunk);
            }
        }
    }

    pub fn notify(&self, updates: Vec<GridUpdate>) {
        let mut update_queue: BTreeMap<usize, Vec<GridUpdate>> = Default::default();
        for update in updates {
            update.visit_chunks(|chunk_x, chunk_y| {
                if let Some(subscribers) = self.chunks.get(&(chunk_x, chunk_y)) {
                    for subscriber in subscribers {
                        update_queue
                            .entry(*subscriber)
                            .or_insert_with(Vec::new)
                            .push(update.clone());
                    }
                }
            });
        }
        for (id, updates) in update_queue {
            self.subscribers[id].1.notify(updates);
        }
    }

    pub fn subscribe_chunks(&mut self, id: usize, chunks: Vec<(usize, usize)>) {
        self.subscribers[id].0.extend(chunks.iter());
        for chunk in chunks {
            self.chunks
                .entry(chunk)
                .or_insert_with(HashSet::new)
                .insert(id);
        }
    }

    pub fn unsubscribe_chunk(&mut self, id: usize, chunk_x: usize, chunk_y: usize) {
        self.subscribers[id].0.remove(&(chunk_x, chunk_y));
        self.chunks
            .get_mut(&(chunk_x, chunk_y))
            .unwrap()
            .remove(&id);
        if self.chunks[&(chunk_x, chunk_y)].len() == 0 {
            self.chunks.remove(&(chunk_x, chunk_y));
        }
    }

    pub fn remove_subscriber(&mut self, id: usize) {
        let (chunks, _) = self.subscribers.remove(id);
        for chunk in chunks {
            self.chunks.get_mut(&chunk).unwrap().remove(&id);
            if self.chunks[&chunk].len() == 0 {
                self.chunks.remove(&chunk);
            }
        }
    }
}
