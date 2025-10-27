const { v4: uuidv4 } = require('uuid');
const PassModel = require('../models/pass.model');
const redisService = require('./redis.service');
const SettingsModel = require('../models/settings.model');
const logger = require('../utils/logger');
const { formatDateForDB } = require('../utils/validators');

class BulkService {
  constructor() {
    this.activeBulkOperations = new Map();
    this.defaultBatchSize = 100;
    this.maxConcurrentOperations = 5;
  }

  async createBulkPassesREST(passesData, createdBy, providedScanId = null) {
    try {
      const scanId = providedScanId || uuidv4(); // Use provided scanId or generate new one
      logger.info(`Using scanId for bulk operation: ${scanId} (${providedScanId ? 'provided' : 'generated'})`);
      const batchSize = await SettingsModel.getBulkBatchSize() || this.defaultBatchSize;
      
      const results = {
        total: passesData.length,
        created: 0,
        duplicates: 0,
        errors: [],
        batches: Math.ceil(passesData.length / batchSize)
      };

      logger.info(`Starting REST bulk creation: ${results.total} passes in ${results.batches} batches`);

      // Process in batches
      for (let i = 0; i < passesData.length; i += batchSize) {
        const batch = passesData.slice(i, i + batchSize);
        const batchNumber = Math.floor(i / batchSize) + 1;
        
        logger.info(`Processing batch ${batchNumber}/${results.batches} (${batch.length} passes)`);
        
        try {
          const batchResult = await this.processBatch(batch, createdBy, batchNumber, scanId);
          
          results.created += batchResult.created;
          results.duplicates += batchResult.duplicates;
          results.errors.push(...batchResult.errors);
          
        } catch (error) {
          logger.error(`Batch ${batchNumber} failed:`, error);
          
          // Add all passes in failed batch to errors
          batch.forEach(pass => {
            results.errors.push({
              uid: pass.uid,
              error: `Batch processing failed: ${error.message}`,
              batch: batchNumber
            });
          });
        }
      }

      logger.info(`REST bulk creation completed: ${results.created}/${results.total} created`);
      return results;
      
    } catch (error) {
      logger.error('REST bulk creation error:', error);
      throw error;
    }
  }

  async createBulkPassesWebSocket(socket, passesData, createdBy) {
    const bulkId = uuidv4();
    const scanId = uuidv4(); // Generate unique scanId for this bulk operation
    const batchSize = await SettingsModel.getBulkBatchSize() || this.defaultBatchSize;
    
    const operation = {
      id: bulkId,
      socket,
      total: passesData.length,
      processed: 0,
      created: 0,
      duplicates: 0,
      errors: [],
      startTime: Date.now(),
      status: 'running'
    };

    this.activeBulkOperations.set(bulkId, operation);

    try {
      logger.info(`Starting WebSocket bulk creation: ${operation.total} passes, bulkId=${bulkId}`);
      
      // Emit start event
      socket.emit('bulk:create:start', {
        bulkId,
        totalExpected: operation.total,
        batchSize
      });

      // Process in batches with progress updates
      for (let i = 0; i < passesData.length; i += batchSize) {
        const batch = passesData.slice(i, i + batchSize);
        const batchNumber = Math.floor(i / batchSize) + 1;
        const totalBatches = Math.ceil(passesData.length / batchSize);
        
        try {
          const batchResult = await this.processBatch(batch, createdBy, batchNumber, scanId);
          
          // Update operation stats
          operation.processed += batch.length;
          operation.created += batchResult.created;
          operation.duplicates += batchResult.duplicates;
          operation.errors.push(...batchResult.errors);
          
          // Emit progress event
          socket.emit('bulk:create:progress', {
            bulkId,
            batchNumber,
            totalBatches,
            processed: operation.processed,
            total: operation.total,
            created: operation.created,
            duplicates: operation.duplicates,
            errorCount: operation.errors.length,
            lastError: operation.errors.length > 0 ? operation.errors[operation.errors.length - 1] : null,
            progressPercent: Math.round((operation.processed / operation.total) * 100)
          });
          
          // Small delay to prevent overwhelming the client
          await new Promise(resolve => setTimeout(resolve, 10));
          
        } catch (error) {
          logger.error(`WebSocket batch ${batchNumber} failed:`, error);
          
          // Add all passes in failed batch to errors
          batch.forEach(pass => {
            operation.errors.push({
              uid: pass.uid,
              error: `Batch processing failed: ${error.message}`,
              batch: batchNumber
            });
          });
          
          operation.processed += batch.length;
          
          // Emit progress with error
          socket.emit('bulk:create:progress', {
            bulkId,
            batchNumber,
            totalBatches,
            processed: operation.processed,
            total: operation.total,
            created: operation.created,
            duplicates: operation.duplicates,
            errorCount: operation.errors.length,
            lastError: operation.errors[operation.errors.length - 1],
            progressPercent: Math.round((operation.processed / operation.total) * 100)
          });
        }
      }

      // Mark operation as completed
      operation.status = 'completed';
      operation.endTime = Date.now();
      operation.duration = operation.endTime - operation.startTime;

      // Emit completion event
      socket.emit('bulk:create:done', {
        bulkId,
        summary: {
          total: operation.total,
          processed: operation.processed,
          created: operation.created,
          duplicates: operation.duplicates,
          errors: operation.errors.length,
          duration: operation.duration,
          successRate: Math.round((operation.created / operation.total) * 100)
        },
        errorDetails: operation.errors.length > 0 ? operation.errors : undefined
      });

      logger.info(`WebSocket bulk creation completed: ${operation.created}/${operation.total} created, bulkId=${bulkId}`);
      
      return {
        bulkId,
        total: operation.total,
        created: operation.created,
        duplicates: operation.duplicates,
        errors: operation.errors
      };
      
    } catch (error) {
      logger.error('WebSocket bulk creation error:', error);
      
      operation.status = 'failed';
      operation.endTime = Date.now();
      
      // Emit error event
      socket.emit('bulk:create:error', {
        bulkId,
        error: error.message,
        processed: operation.processed,
        created: operation.created
      });
      
      throw error;
    } finally {
      // Clean up operation after 5 minutes
      setTimeout(() => {
        this.activeBulkOperations.delete(bulkId);
      }, 5 * 60 * 1000);
    }
  }

 async processBatch(batch, createdBy, batchNumber, scanId = null) {
    try {
      logger.info(`Processing batch ${batchNumber} with scanId: ${scanId}`);
      const results = {
        created: 0,
        duplicates: 0,
        errors: []
      };
      // Validate and prepare batch data
      const validPasses = [];
      const uidsToCheck = batch.map(pass => pass.uid);
      
      // Check for duplicates within the batch
      const uniqueUids = [...new Set(uidsToCheck)];
      if (uidsToCheck.length !== uniqueUids.length) {
        // Find duplicate UIDs (preserve first occurrence, mark later ones as duplicates)
        const seenUids = new Set();
        const duplicateUids = [];
        
        uidsToCheck.forEach(uid => {
          if (seenUids.has(uid)) {
            duplicateUids.push(uid);
          } else {
            seenUids.add(uid);
          }
        });
        
        duplicateUids.forEach(uid => {
          results.duplicates++;
          results.errors.push({
            uid,
            error: 'Duplicate UID within batch',
            batch: batchNumber
          });
        });
      }

      // Check for existing UIDs in database
      const existingChecks = await Promise.all(
        uniqueUids.map(uid => PassModel.isUidExists(uid))
      );
      
      const existingUids = new Set(
        uniqueUids.filter((uid, index) => existingChecks[index])
      );

      // Prepare valid passes for creation (only process first occurrence of each UID)
      const processedUids = new Set();
      
      for (const pass of batch) {
        if (existingUids.has(pass.uid)) {
          results.duplicates++;
          results.errors.push({
            uid: pass.uid,
            error: 'UID already exists in database',
            batch: batchNumber
          });
        } else if (uniqueUids.includes(pass.uid) && !processedUids.has(pass.uid)) {
          // Mark this UID as processed to skip later duplicates
          processedUids.add(pass.uid);
          
          // Validate pass data
          const validationErrors = await this.validatePassData(pass);
          if (validationErrors.length > 0) {
            results.errors.push({
              uid: pass.uid,
              error: `Validation failed: ${validationErrors.join(', ')}`,
              batch: batchNumber
            });
          } else {
            const passWithScanId = {
              ...pass,
              created_by: createdBy,
               scanId
            };
            logger.info(`Adding pass to validPasses with scanId: ${passWithScanId.scanId} for UID: ${passWithScanId.uid}`);
            validPasses.push(passWithScanId);
          }
        }
      }

      // Create valid passes in database
      if (validPasses.length > 0) {
        const createdPasses = await PassModel.createBulk(validPasses);
        results.created = createdPasses.length;

        // Add active passes to Redis cache (in background)
        this.addPassesToRedisCache(validPasses).catch(error => {
          logger.error('Failed to add batch passes to Redis cache:', error);
        });
      }

      return results;
      
    } catch (error) {
      logger.error(`Batch ${batchNumber} processing error:`, error);
      throw error;
    }
  }

  async addPassesToRedisCache(passes) {
    try {
      const activePassPromises = passes
        .filter(pass => !pass.status || pass.status === 'active')
        .map(async (pass) => {
          try {
            const fullPass = await PassModel.findByUid(pass.uid);
            if (fullPass) {
              await redisService.addActivePass(pass.uid, fullPass);
            }
          } catch (error) {
            logger.error(`Failed to add pass ${pass.uid} to Redis:`, error);
          }
        });

      await Promise.allSettled(activePassPromises);
    } catch (error) {
      logger.error('Error adding passes to Redis cache:', error);
    }
  }

  async validatePassData(passData) {
    const errors = [];

    // Validate UID format
    if (!passData.uid || !/^[a-zA-Z0-9]{4,128}$/.test(passData.uid)) {
      errors.push('UID must be 4-128 alphanumeric characters');
    }

    // Validate pass type
    if (!['daily', 'seasonal', 'unlimited'].includes(passData.pass_type)) {
      errors.push('Pass type must be daily, seasonal, or unlimited');
    }

    // Validate category
    if (!passData.category || passData.category.trim().length === 0) {
      errors.push('Category is required');
    }

    // Validate people allowed
    if (!passData.people_allowed || passData.people_allowed < 1 || passData.people_allowed > 100) {
      errors.push('People allowed must be between 1 and 100');
    }

    return errors;
  }

  getBulkOperationStatus(bulkId) {
    return this.activeBulkOperations.get(bulkId) || null;
  }

  getAllActiveBulkOperations() {
    return Array.from(this.activeBulkOperations.values()).map(op => ({
      id: op.id,
      total: op.total,
      processed: op.processed,
      created: op.created,
      duplicates: op.duplicates,
      errorCount: op.errors.length,
      status: op.status,
      startTime: op.startTime,
      duration: op.endTime ? op.endTime - op.startTime : Date.now() - op.startTime
    }));
  }

  cancelBulkOperation(bulkId) {
    const operation = this.activeBulkOperations.get(bulkId);
    if (operation && operation.status === 'running') {
      operation.status = 'cancelled';
      operation.endTime = Date.now();
      
      // Emit cancellation event
      if (operation.socket) {
        operation.socket.emit('bulk:create:cancelled', {
          bulkId,
          processed: operation.processed,
          created: operation.created
        });
      }
      
      return true;
    }
    return false;
  }

  async getActiveBulkOperationsCount() {
    return this.activeBulkOperations.size;
  }

  async canStartNewBulkOperation() {
    const activeCount = await this.getActiveBulkOperationsCount();
    return activeCount < this.maxConcurrentOperations;
  }
}

module.exports = new BulkService();