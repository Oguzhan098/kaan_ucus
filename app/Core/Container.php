<?php
namespace App\Core;

final class Container {
    /** @var array<string, mixed> */
    private static $items = [];

    /** @param mixed $value */
    public static function set(string $key, $value): void {
        self::$items[$key] = $value;
    }

    /**
     * @param mixed $default
     * @return mixed
     */
    public static function get(string $key, $default = null) {
        return array_key_exists($key, self::$items) ? self::$items[$key] : $default;
    }
}
