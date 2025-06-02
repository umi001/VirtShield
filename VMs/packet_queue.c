#include "packet_queue.h"

void init_queue(PacketQueue *q) {
    q->front = q->rear = NULL;
}

void enqueue(PacketQueue *q, uint64_t timestamp) {
    PacketNode *new_node = (PacketNode *)malloc(sizeof(PacketNode));
    new_node->timestamp = timestamp;
    new_node->next = NULL;

    if (q->rear == NULL) {
        q->front = q->rear = new_node;
        return;
    }

    q->rear->next = new_node;
    q->rear = new_node;
}

int dequeue(PacketQueue *q, uint64_t *timestamp) {
    if (q->front == NULL)
        return 0;

    PacketNode *temp = q->front;
    *timestamp = temp->timestamp;
    q->front = q->front->next;

    if (q->front == NULL)
        q->rear = NULL;

    free(temp);
    return 1;
}

int is_queue_empty(PacketQueue *q) {
    return q->front == NULL;
}
