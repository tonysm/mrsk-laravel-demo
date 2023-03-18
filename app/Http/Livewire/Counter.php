<?php

namespace App\Http\Livewire;

use Illuminate\Support\Facades\Redis;
use Livewire\Component;
use Predis\Client;
use Predis\Command\Redis\SETNX;

class Counter extends Component
{
    public $count;

    public function mount()
    {
        $this->refreshCount();
    }

    public function increment()
    {
        $this->count = Redis::incr('counter');
    }

    public function refreshCount()
    {
        $this->count = Redis::get('counter') ?? 0;
    }

    public function render()
    {
        return view('livewire.counter');
    }
}
