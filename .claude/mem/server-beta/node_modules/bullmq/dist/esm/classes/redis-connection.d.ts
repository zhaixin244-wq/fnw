import { EventEmitter } from 'events';
import { ConnectionOptions, RedisClient } from '../interfaces';
import { DatabaseType } from '../types';
interface RedisCapabilities {
    canDoubleTimeout: boolean;
    canBlockFor1Ms: boolean;
}
export interface RawCommand {
    content: string;
    name: string;
    keys: number;
}
export declare class RedisConnection extends EventEmitter {
    private readonly extraOptions?;
    static minimumVersion: string;
    static recommendedMinimumVersion: string;
    closing: boolean;
    capabilities: RedisCapabilities;
    status: 'initializing' | 'ready' | 'closing' | 'closed';
    private dbType;
    protected _client: RedisClient;
    private readonly opts;
    private readonly initializing;
    private version;
    protected packageVersion: string;
    private skipVersionCheck;
    private handleClientError;
    private handleClientClose;
    private handleClientReady;
    private patchedBlockingClusterClient?;
    private disabledBlockingClusterReconnect;
    constructor(opts: ConnectionOptions, extraOptions?: {
        shared?: boolean;
        blocking?: boolean;
        skipVersionCheck?: boolean;
        skipWaitingForReady?: boolean;
    });
    private checkBlockingOptions;
    /**
     * Waits for a redis client to be ready.
     * @param redis - client
     */
    static waitUntilReady(client: RedisClient): Promise<void>;
    get client(): Promise<RedisClient>;
    protected loadCommands(packageVersion: string, providedScripts?: Record<string, RawCommand>): void;
    private init;
    private patchBlockingClusterClient;
    private disableBlockingClusterReconnect;
    private releaseBlockingClusterClientPatch;
    private static isClusterWithEmptyNodes;
    private static isReconnectingDisabled;
    private static reconnectClusterIfNeeded;
    private static shouldReconnectClusterAfterError;
    private static reconnectCluster;
    disconnect(wait?: boolean): Promise<void>;
    reconnect(): Promise<void>;
    close(force?: boolean): Promise<void>;
    private getRedisVersionAndType;
    get redisVersion(): string;
    get databaseType(): DatabaseType;
}
export {};
