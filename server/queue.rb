class QueueWithTimeout
  def initialize
    @mutex = Mutex.new
    @queue = []
    @received = ConditionVariable.new
  end
 
  def <<(x)
    @mutex.synchronize do
      @queue << x
      @received.signal
    end
  end
 
  def pop(non_block = false)
    pop_with_timeout(non_block ? 0 : nil)
  end
 
  def pop_with_timeout(timeout = nil)
    @mutex.synchronize do
      if timeout.nil?
        # wait indefinitely until there is an element in the queue
        while @queue.empty?
          @received.wait(@mutex)
        end
      elsif @queue.empty? && timeout != 0
        # wait for element or timeout
        timeout_time = timeout + Time.now.to_f
        while @queue.empty? && (remaining_time = timeout_time - Time.now.to_f) > 0
          @received.wait(@mutex, remaining_time)
        end
      end
      #if we're still empty after the timeout, raise exception
      raise ThreadError, "queue empty" if @queue.empty?
      @queue.shift
    end
  end
end
