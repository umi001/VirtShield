#ifndef PACKET_QUEUE_H
#define PACKET_QUEUE_H

#include <stdint.h>
#include <stdlib.h>

typedef struct PacketNode {
    uint64_t timestamp;
    struct PacketNode *next;
} PacketNode;

typedef struct {
    PacketNode *front;
    PacketNode *rear;
} PacketQueue;

void init_queue(PacketQueue *q);
void enqueue(PacketQueue *q, uint64_t timestamp);
int dequeue(PacketQueue *q, uint64_t *timestamp);
int is_queue_empty(PacketQueue *q);

#endif
