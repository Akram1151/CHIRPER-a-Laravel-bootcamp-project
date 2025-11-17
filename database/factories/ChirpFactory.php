<?php
namespace Database\Factories;

use App\Models\Chirp;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends \Illuminate\Database\Eloquent\Factories\Factory<\App\Models\Chirp>
 */
class ChirpFactory extends Factory
{
    protected $model = Chirp::class;

    public function definition(): array
    {
        return [
            'message' => $this->faker->sentence(), // Genera un missatge aleatori
            'user_id' => \App\Models\User::factory(), // Crea un usuari associat
        ];
    }
}